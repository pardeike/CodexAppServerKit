import Foundation

/// Errors surfaced by CodexAppServerKit.
public enum CodexError: Error, Sendable, Equatable, LocalizedError {
    case executableNotFound(searchedNames: [String])
    case processAlreadyRunning
    case processNotRunning
    case processExited(status: Int32)
    case processLaunchFailed(String)
    case malformedMessage(String)
    case missingField(String)
    case invalidURL(String)
    case rpcError(code: Int, message: String, data: CodexJSONValue?)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .executableNotFound(let searchedNames):
            return "Could not find the bundled Codex executable. Searched: \(searchedNames.joined(separator: ", "))."
        case .processAlreadyRunning:
            return "The Codex app-server process is already running."
        case .processNotRunning:
            return "The Codex app-server process is not running."
        case .processExited(let status):
            return "The Codex app-server process exited with status \(status)."
        case .processLaunchFailed(let message):
            return "Could not launch Codex app-server: \(message)"
        case .malformedMessage(let line):
            return "Codex app-server returned malformed JSON-RPC: \(line)"
        case .missingField(let name):
            return "Expected field is missing: \(name)"
        case .invalidURL(let value):
            return "Invalid URL: \(value)"
        case .rpcError(let code, let message, _):
            return "Codex app-server RPC error \(code): \(message)"
        case .cancelled:
            return "The operation was cancelled."
        }
    }
}
