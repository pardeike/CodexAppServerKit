import Foundation

public struct CodexClientInfo: Sendable, Hashable, Codable {
    public var name: String
    public var title: String
    public var version: String

    public init(name: String, title: String, version: String) {
        self.name = name
        self.title = title
        self.version = version
    }
}

/// Launch configuration for a bundled `codex app-server` executable.
///
/// The package intentionally does not ship the Codex executable. Add your own signed helper to the host app bundle
/// and pass its URL here, or use `bundledExecutable(named:)` to find it from the app bundle.
public struct CodexAppServerConfiguration: Sendable, Hashable {
    public var executableURL: URL
    public var arguments: [String]
    public var environment: [String: String]
    public var workingDirectoryURL: URL?
    public var codexHomeDirectory: URL?
    public var clientInfo: CodexClientInfo
    public var optOutNotificationMethods: [String]

    public init(
        executableURL: URL,
        arguments: [String] = ["app-server"],
        environment: [String: String] = [:],
        workingDirectoryURL: URL? = nil,
        codexHomeDirectory: URL? = Self.defaultCodexHomeDirectory(),
        clientInfo: CodexClientInfo,
        optOutNotificationMethods: [String] = []
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.workingDirectoryURL = workingDirectoryURL
        self.codexHomeDirectory = codexHomeDirectory
        self.clientInfo = clientInfo
        self.optOutNotificationMethods = optOutNotificationMethods
    }

    /// Finds a helper executable copied into the app bundle's `Contents/MacOS` or `Contents/Helpers` area.
    public static func bundledExecutable(named name: String = "codex", bundle: Bundle = .main) throws -> URL {
        var searched: [String] = []

        if let url = bundle.url(forAuxiliaryExecutable: name) {
            return url
        }
        searched.append("Bundle.main.url(forAuxiliaryExecutable: \"\(name)\")")

        if let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "Helpers") {
            return url
        }
        searched.append("Bundle.main.url(forResource: \"\(name)\", subdirectory: \"Helpers\")")

        if let url = bundle.url(forResource: name, withExtension: nil) {
            return url
        }
        searched.append("Bundle.main.url(forResource: \"\(name)\")")

        throw CodexError.executableNotFound(searchedNames: searched)
    }

    /// A sandbox-friendly Codex home inside Application Support.
    /// In a sandboxed Mac App Store app, this resolves inside the app container.
    public static func defaultCodexHomeDirectory(
        applicationSupportDirectoryName: String? = Bundle.main.bundleIdentifier
    ) -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        let name = applicationSupportDirectoryName ?? "CodexAppServerKit"
        return appSupport
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent("CodexHome", isDirectory: true)
    }

    func preparedEnvironment() throws -> [String: String] {
        var result = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            result[key] = value
        }

        if let codexHomeDirectory {
            try FileManager.default.createDirectory(at: codexHomeDirectory, withIntermediateDirectories: true)
            result["CODEX_HOME"] = codexHomeDirectory.path
        }

        return result
    }
}
