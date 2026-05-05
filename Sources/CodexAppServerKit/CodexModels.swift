import Foundation

public struct CodexAccountReadResult: Codable, Sendable, Equatable {
    public let account: CodexAccount?
    public let requiresOpenaiAuth: Bool?

    public init(account: CodexAccount?, requiresOpenaiAuth: Bool?) {
        self.account = account
        self.requiresOpenaiAuth = requiresOpenaiAuth
    }
}

public struct CodexAccount: Codable, Sendable, Equatable {
    public let type: String
    public let email: String?
    public let planType: String?

    public init(type: String, email: String? = nil, planType: String? = nil) {
        self.type = type
        self.email = email
        self.planType = planType
    }
}

public struct CodexLoginStartResult: Codable, Sendable, Equatable {
    public let type: String
    public let loginId: String?
    public let authUrl: String?
    public let verificationUrl: String?
    public let userCode: String?

    public init(
        type: String,
        loginId: String? = nil,
        authUrl: String? = nil,
        verificationUrl: String? = nil,
        userCode: String? = nil
    ) {
        self.type = type
        self.loginId = loginId
        self.authUrl = authUrl
        self.verificationUrl = verificationUrl
        self.userCode = userCode
    }

    public var authURL: URL? {
        guard let authUrl else { return nil }
        return URL(string: authUrl)
    }

    public var verificationURL: URL? {
        guard let verificationUrl else { return nil }
        return URL(string: verificationUrl)
    }

    public var isDeviceCodeFlow: Bool {
        type == "chatgptDeviceCode" || verificationUrl != nil || userCode != nil
    }
}

public struct CodexLoginCompletedNotification: Codable, Sendable, Equatable {
    public let loginId: String?
    public let success: Bool
    public let error: String?

    public init(loginId: String?, success: Bool, error: String?) {
        self.loginId = loginId
        self.success = success
        self.error = error
    }
}

public struct CodexAccountUpdatedNotification: Codable, Sendable, Equatable {
    public let authMode: String?
    public let planType: String?

    public init(authMode: String?, planType: String?) {
        self.authMode = authMode
        self.planType = planType
    }
}

public struct CodexRateLimitsReadResult: Codable, Sendable, Equatable {
    public let rateLimits: CodexRateLimitBucket?
    public let rateLimitsByLimitId: [String: CodexRateLimitBucket]?

    public init(rateLimits: CodexRateLimitBucket?, rateLimitsByLimitId: [String: CodexRateLimitBucket]? = nil) {
        self.rateLimits = rateLimits
        self.rateLimitsByLimitId = rateLimitsByLimitId
    }

    /// Prefer the documented Codex bucket, falling back to the legacy single-bucket response.
    public var preferredBucket: CodexRateLimitBucket? {
        rateLimitsByLimitId?["codex"] ?? rateLimits ?? rateLimitsByLimitId?.values.first
    }

    public var sortedBuckets: [CodexRateLimitBucket] {
        if let values = rateLimitsByLimitId?.values {
            return values.sorted { lhs, rhs in
                (lhs.displayName, lhs.limitId ?? "") < (rhs.displayName, rhs.limitId ?? "")
            }
        }
        return rateLimits.map { [$0] } ?? []
    }
}

public struct CodexRateLimitBucket: Codable, Sendable, Equatable, Identifiable {
    public let limitId: String?
    public let limitName: String?
    public let primary: CodexRateLimitWindow?
    public let secondary: CodexRateLimitWindow?
    public let rateLimitReachedType: String?
    public let planType: String?
    public let credits: CodexJSONValue?

    public var id: String { limitId ?? limitName ?? "unknown" }

    public init(
        limitId: String?,
        limitName: String? = nil,
        primary: CodexRateLimitWindow? = nil,
        secondary: CodexRateLimitWindow? = nil,
        rateLimitReachedType: String? = nil,
        planType: String? = nil,
        credits: CodexJSONValue? = nil
    ) {
        self.limitId = limitId
        self.limitName = limitName
        self.primary = primary
        self.secondary = secondary
        self.rateLimitReachedType = rateLimitReachedType
        self.planType = planType
        self.credits = credits
    }

    public var displayName: String {
        limitName ?? limitId ?? "Codex"
    }
}

public struct CodexRateLimitWindow: Codable, Sendable, Equatable {
    public let usedPercent: Double?
    public let windowDurationMins: Double?
    public let resetsAt: Double?

    public init(usedPercent: Double?, windowDurationMins: Double?, resetsAt: Double?) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }

    public var clampedUsedPercent: Double {
        min(max(usedPercent ?? 0, 0), 100)
    }

    public var resetDate: Date? {
        guard let resetsAt else { return nil }
        return Date(timeIntervalSince1970: resetsAt)
    }
}
