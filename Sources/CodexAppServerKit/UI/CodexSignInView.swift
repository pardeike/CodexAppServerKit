#if os(macOS)
import AppKit
import SwiftUI

public struct CodexSignInView: View {
    @ObservedObject private var controller: CodexRateLimitController
    @Environment(\.openURL) private var openURL

    public init(controller: CodexRateLimitController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            switch controller.state {
            case .idle, .starting:
                startingView
            case .needsSignIn:
                signInOptions
            case .signingIn:
                signingInView
            case .ready:
                signedInView
            case .failed:
                failedView
            }
        }
        .padding(20)
        .frame(minWidth: 380, idealWidth: 420, maxWidth: 520, alignment: .leading)
        .task {
            await controller.connect()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Codex Account", systemImage: "person.crop.circle.badge.checkmark")
                .font(.title2.weight(.semibold))
            Text("Sign in locally through the bundled Codex app-server. Your app talks to Codex over stdio, not a local port.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var startingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Starting Codex…")
        }
    }

    private var signInOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Codex needs a ChatGPT sign-in before rate-limit data is available.")
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    if let login = await controller.beginDeviceCodeLogin(), let url = login.verificationURL {
                        openURL(url)
                    }
                }
            } label: {
                Label("Sign in with device code", systemImage: "rectangle.and.pencil.and.ellipsis")
            }
            .buttonStyle(.borderedProminent)

            Button {
                Task {
                    if let url = await controller.beginBrowserLogin() {
                        openURL(url)
                    }
                }
            } label: {
                Label("Sign in in browser", systemImage: "safari")
            }
            .help("Browser sign-in needs a local callback listener. Device-code sign-in is usually simpler for a sandboxed App Store app.")

            errorText
        }
    }

    @ViewBuilder
    private var signingInView: some View {
        if let login = controller.activeLogin, login.isDeviceCodeFlow {
            deviceCodeView(login)
        } else {
            browserWaitingView
        }
    }

    private func deviceCodeView(_ login: CodexLoginStartResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter this code in your browser:")
                .font(.headline)

            Text(login.userCode ?? "—")
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
                .textSelection(.enabled)
                .padding(.vertical, 6)

            HStack {
                Button {
                    if let code = login.userCode {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                    }
                } label: {
                    Label("Copy code", systemImage: "doc.on.doc")
                }

                Button {
                    if let url = login.verificationURL {
                        openURL(url)
                    }
                } label: {
                    Label("Open sign-in page", systemImage: "arrow.up.forward.app")
                }
            }

            HStack(spacing: 10) {
                ProgressView()
                Text("Waiting for Codex to confirm sign-in…")
                    .foregroundStyle(.secondary)
            }

            Button("Cancel sign-in", role: .cancel) {
                controller.cancelLogin()
            }

            errorText
        }
    }

    private var browserWaitingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                Text("Complete sign-in in your browser…")
            }

            Button("Cancel sign-in", role: .cancel) {
                controller.cancelLogin()
            }

            errorText
        }
    }

    private var signedInView: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let account = controller.account {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "checkmark.seal")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.email ?? "Signed in")
                            .font(.headline)
                        if let planType = account.planType {
                            Text(planType.capitalized)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            CodexRateLimitStatusView(rateLimits: controller.rateLimits)

            HStack {
                Button {
                    controller.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button("Sign out") {
                    controller.logout()
                }
            }

            errorText
        }
    }

    private var failedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Could not start Codex", systemImage: "exclamationmark.triangle")
                .font(.headline)
            errorText
            Button {
                Task { await controller.connect() }
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
            }
        }
    }

    @ViewBuilder
    private var errorText: some View {
        if let message = controller.lastErrorMessage, !message.isEmpty {
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
