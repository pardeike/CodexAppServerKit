import Foundation

/// A small Codable JSON value type used for JSON-RPC params/results whose exact schema can evolve with Codex.
public enum CodexJSONValue: Sendable, Equatable, Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([CodexJSONValue])
    case object([String: CodexJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([CodexJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: CodexJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

public extension CodexJSONValue {
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .double(let value): return Int(value)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .int(let value): return Double(value)
        case .double(let value): return value
        default: return nil
        }
    }

    var arrayValue: [CodexJSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var objectValue: [String: CodexJSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    subscript(key: String) -> CodexJSONValue? {
        guard case .object(let object) = self else { return nil }
        return object[key]
    }

    func decoded<T: Decodable>(as type: T.Type = T.self, using decoder: JSONDecoder = JSONDecoder()) throws -> T {
        let data = try JSONEncoder.codexRPC.encode(self)
        return try decoder.decode(T.self, from: data)
    }

    static func encoded<T: Encodable>(_ value: T) throws -> CodexJSONValue {
        let data = try JSONEncoder.codexRPC.encode(value)
        return try JSONDecoder.codexRPC.decode(CodexJSONValue.self, from: data)
    }
}

extension JSONEncoder {
    static var codexRPC: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }
}

extension JSONDecoder {
    static var codexRPC: JSONDecoder {
        JSONDecoder()
    }
}
