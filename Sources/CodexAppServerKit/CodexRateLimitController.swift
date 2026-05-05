#if os(macOS)
import AppKit
import Combine
import Foundation

public enum CodexRateLimitControllerState: String, Sendable, Equatable {
    case idle
    case starting
    case needsSignIn
    case signingIn
    case ready
    case failed
}

/// Main-actor view model for menu-bar/status-window integrations.
@MainActor
public final class CodexRateLimitController: ObservableObject {
    @Published public private(set) var state: CodexRateLimitControllerState = .idle
    @Published public private(set) var account: CodexAccount?
    @Published public private(set) var requiresOpenaiAuth = true
    @Published public private(set) var rateLimits: CodexRateLimitsReadResult?
    @Published public private(set) var activeLogin: CodexLoginStartResult?
    @Published public private(set) var lastErrorMessage: String?
    @Published public private(set) var diagnosticLines: [String] = []

    public let configuration: CodexAppServerConfiguration

    private let client: CodexAppServerClient
    private var notificationTask: Task<Void, Never>?
    private var diagnosticTask: Task<Void, Never>?

    public init(configuration: CodexAppServerConfiguration) {
        self.configuration = configuration
        self.client = CodexAppServerClient(configuration: configuration)
    }

    deinit {
        notificationTask?.cancel()
        diagnosticTask?.cancel()
    }

    public func start() {
        Task { await connect() }
    }

    public func connect() async {
        guard state == .idle || state == .failed else { return }
        state = .starting
        lastErrorMessage = nil

        do {
            try await client.start()
            startObservationIfNeeded()
            try await refreshAccountAndLimits()
        } catch {
            fail(error)
        }
    }

    public func refresh() {
        Task { await refreshAccountAndLimits() }
    }

    public func refreshAccountAndLimits() async {
        do {
            let accountResult = try await client.readAccount(refreshToken: false)
            account = accountResult.account
            requiresOpenaiAuth = accountResult.requiresOpenaiAuth ?? true

            if accountResult.account == nil, requiresOpenaiAuth {
                rateLimits = nil
                state = .needsSignIn
                return
            }

            state = .ready
            await refreshRateLimits()
        } catch {
            fail(error)
        }
    }

    public func refreshRateLimits() async {
        do {
            rateLimits = try await client.readRateLimits()
            lastErrorMessage = nil
            if state != .signingIn {
                state = .ready
            }
        } catch {
            // Keep the signed-in UI usable even when rate-limit refresh fails temporarily.
            lastErrorMessage = error.localizedDescription
            if account == nil {
                state = .needsSignIn
            }
        }
    }

    /// Starts the browser-based ChatGPT OAuth flow. The caller owns opening the returned URL.
    /// This flow requires a local callback listener in the app-server; in a sandboxed app that usually means
    /// adding the `com.apple.security.network.server` entitlement. Prefer `beginDeviceCodeLogin()` for least privilege.
    @discardableResult
    public func beginBrowserLogin() async -> URL? {
        state = .signingIn
        lastErrorMessage = nil

        do {
            let login = try await client.startChatGPTLogin()
            activeLogin = login
            guard let url = login.authURL else {
                throw CodexError.missingField("authUrl")
            }
            return url
        } catch {
            fail(error)
            return nil
        }
    }

    /// Starts the device-code ChatGPT flow. This is the recommended sandbox/App Store sign-in ceremony.
    @discardableResult
    public func beginDeviceCodeLogin() async -> CodexLoginStartResult? {
        state = .signingIn
        lastErrorMessage = nil

        do {
            let login = try await client.startChatGPTDeviceCodeLogin()
            activeLogin = login
            return login
        } catch {
            fail(error)
            return nil
        }
    }

    public func cancelLogin() {
        guard let loginId = activeLogin?.loginId else {
            activeLogin = nil
            state = account == nil ? .needsSignIn : .ready
            return
        }

        Task {
            do {
                try await client.cancelLogin(loginId: loginId)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
            activeLogin = nil
            state = account == nil ? .needsSignIn : .ready
        }
    }

    public func logout() {
        Task {
            do {
                try await client.logout()
                account = nil
                rateLimits = nil
                activeLogin = nil
                state = .needsSignIn
            } catch {
                fail(error)
            }
        }
    }

    public func stop() {
        notificationTask?.cancel()
        diagnosticTask?.cancel()
        notificationTask = nil
        diagnosticTask = nil
        Task {
            await client.stop()
            state = .idle
        }
    }

    private func startObservationIfNeeded() {
        guard notificationTask == nil else { return }

        let client = self.client
        notificationTask = Task { [weak self] in
            for await notification in client.notifications {
                await self?.handle(notification)
            }
        }

        diagnosticTask = Task { [weak self] in
            for await line in client.diagnostics {
                await self?.appendDiagnostic(line)
            }
        }
    }

    private func appendDiagnostic(_ line: String) {
        diagnosticLines.append(line)
        if diagnosticLines.count > 200 {
            diagnosticLines.removeFirst(diagnosticLines.count - 200)
        }
    }

    private func handle(_ notification: CodexNotification) async {
        switch notification.method {
        case "account/login/completed":
            do {
                let completed = try notification.decodedParams(as: CodexLoginCompletedNotification.self)
                activeLogin = nil
                if completed.success {
                    lastErrorMessage = nil
                    await refreshAccountAndLimits()
                } else {
                    lastErrorMessage = completed.error ?? "Sign-in was cancelled or failed."
                    state = account == nil ? .needsSignIn : .ready
                }
            } catch {
                lastErrorMessage = error.localizedDescription
            }

        case "account/updated":
            await refreshAccountAndLimits()

        case "account/rateLimits/updated":
            do {
                rateLimits = try notification.decodedParams(as: CodexRateLimitsReadResult.self)
                if state != .signingIn {
                    state = .ready
                }
            } catch {
                lastErrorMessage = error.localizedDescription
            }

        default:
            break
        }
    }

    private func fail(_ error: Error) {
        lastErrorMessage = error.localizedDescription
        state = .failed
    }
}
#endif
