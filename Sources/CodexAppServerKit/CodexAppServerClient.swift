import Foundation

/// High-level account/rate-limit API over `codex app-server`.
public actor CodexAppServerClient {
    private let configuration: CodexAppServerConfiguration
    private let connection: CodexAppServerConnection
    private var initialized = false

    public nonisolated var notifications: AsyncStream<CodexNotification> { connection.notifications }
    public nonisolated var diagnostics: AsyncStream<String> { connection.diagnostics }

    public init(configuration: CodexAppServerConfiguration) {
        self.configuration = configuration
        self.connection = CodexAppServerConnection(configuration: configuration)
    }

    public func start() async throws {
        try await connection.start()
        if !initialized {
            try await initialize()
            initialized = true
        }
    }

    public func stop() async {
        await connection.stop()
        initialized = false
    }

    public func readAccount(refreshToken: Bool = false) async throws -> CodexAccountReadResult {
        let params: CodexJSONValue = .object([
            "refreshToken": .bool(refreshToken)
        ])
        let result = try await connection.request(method: "account/read", params: params)
        return try result.decoded(as: CodexAccountReadResult.self)
    }

    public func startChatGPTLogin() async throws -> CodexLoginStartResult {
        let params: CodexJSONValue = .object([
            "type": .string("chatgpt")
        ])
        let result = try await connection.request(method: "account/login/start", params: params)
        return try result.decoded(as: CodexLoginStartResult.self)
    }

    public func startChatGPTDeviceCodeLogin() async throws -> CodexLoginStartResult {
        let params: CodexJSONValue = .object([
            "type": .string("chatgptDeviceCode")
        ])
        let result = try await connection.request(method: "account/login/start", params: params)
        return try result.decoded(as: CodexLoginStartResult.self)
    }

    public func startAPIKeyLogin(apiKey: String) async throws -> CodexLoginStartResult {
        let params: CodexJSONValue = .object([
            "type": .string("apiKey"),
            "apiKey": .string(apiKey)
        ])
        let result = try await connection.request(method: "account/login/start", params: params)
        return try result.decoded(as: CodexLoginStartResult.self)
    }

    public func cancelLogin(loginId: String) async throws {
        let params: CodexJSONValue = .object([
            "loginId": .string(loginId)
        ])
        _ = try await connection.request(method: "account/login/cancel", params: params)
    }

    public func logout() async throws {
        _ = try await connection.request(method: "account/logout")
    }

    public func readRateLimits() async throws -> CodexRateLimitsReadResult {
        let result = try await connection.request(method: "account/rateLimits/read")
        return try result.decoded(as: CodexRateLimitsReadResult.self)
    }

    private func initialize() async throws {
        var params: [String: CodexJSONValue] = [
            "clientInfo": .object([
                "name": .string(configuration.clientInfo.name),
                "title": .string(configuration.clientInfo.title),
                "version": .string(configuration.clientInfo.version)
            ])
        ]

        if !configuration.optOutNotificationMethods.isEmpty {
            params["capabilities"] = .object([
                "optOutNotificationMethods": .array(configuration.optOutNotificationMethods.map { .string($0) })
            ])
        }

        _ = try await connection.request(method: "initialize", params: .object(params))
        try await connection.notify(method: "initialized")
    }
}
