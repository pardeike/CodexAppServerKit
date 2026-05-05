import Foundation

struct CodexJSONRPCRequest: Encodable, Sendable {
    let method: String
    let id: Int?
    let params: CodexJSONValue?

    enum CodingKeys: String, CodingKey {
        case method
        case id
        case params
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(method, forKey: .method)
        if let id {
            try container.encode(id, forKey: .id)
        }
        if let params {
            try container.encode(params, forKey: .params)
        }
    }
}

struct CodexJSONRPCResponse: Encodable, Sendable {
    let id: Int
    let result: CodexJSONValue?
    let error: CodexJSONRPCError?

    enum CodingKeys: String, CodingKey {
        case id
        case result
        case error
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        if let result {
            try container.encode(result, forKey: .result)
        }
        if let error {
            try container.encode(error, forKey: .error)
        }
    }
}

public struct CodexJSONRPCError: Codable, Sendable, Equatable {
    public let code: Int
    public let message: String
    public let data: CodexJSONValue?

    public init(code: Int, message: String, data: CodexJSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

struct CodexJSONRPCIncomingMessage: Decodable, Sendable {
    let id: Int?
    let method: String?
    let params: CodexJSONValue?
    let result: CodexJSONValue?
    let error: CodexJSONRPCError?
}

public struct CodexNotification: Sendable, Equatable {
    public let method: String
    public let params: CodexJSONValue?

    public init(method: String, params: CodexJSONValue? = nil) {
        self.method = method
        self.params = params
    }

    public func decodedParams<T: Decodable>(as type: T.Type = T.self) throws -> T {
        guard let params else {
            throw CodexError.missingField("params")
        }
        return try params.decoded(as: T.self)
    }
}
