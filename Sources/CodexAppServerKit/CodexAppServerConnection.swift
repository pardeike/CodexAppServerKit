import Foundation

typealias CodexPendingContinuation = CheckedContinuation<CodexJSONValue, Error>

/// Low-level JSON-RPC transport for `codex app-server` over stdio.
public actor CodexAppServerConnection {
    private let configuration: CodexAppServerConfiguration
    private var process: Process?
    private var stdin: FileHandle?
    private var stdoutReadTask: Task<Void, Never>?
    private var stderrReadTask: Task<Void, Never>?
    private var nextRequestID = 1
    private var pending: [Int: CodexPendingContinuation] = [:]

    private let notificationsBox = CodexAsyncStreamBox<CodexNotification>()
    private let diagnosticsBox = CodexAsyncStreamBox<String>(bufferingPolicy: .bufferingNewest(200))

    public nonisolated var notifications: AsyncStream<CodexNotification> { notificationsBox.stream }
    public nonisolated var diagnostics: AsyncStream<String> { diagnosticsBox.stream }

    public init(configuration: CodexAppServerConfiguration) {
        self.configuration = configuration
    }

    public func start() async throws {
        guard process == nil else { return }

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errorOutput = Pipe()

        process.executableURL = configuration.executableURL
        process.arguments = configuration.arguments
        process.environment = try configuration.preparedEnvironment()
        process.currentDirectoryURL = configuration.workingDirectoryURL ?? configuration.codexHomeDirectory
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorOutput

        do {
            try process.run()
        } catch {
            throw CodexError.processLaunchFailed(error.localizedDescription)
        }

        self.process = process
        self.stdin = input.fileHandleForWriting
        startStdoutReader(fileHandle: output.fileHandleForReading)
        startStderrReader(fileHandle: errorOutput.fileHandleForReading)
    }

    public func stop() {
        stdoutReadTask?.cancel()
        stderrReadTask?.cancel()
        stdoutReadTask = nil
        stderrReadTask = nil

        stdin?.closeFile()
        stdin = nil

        if let process, process.isRunning {
            process.terminate()
        }
        process = nil

        failAllPending(with: CodexError.processNotRunning)
    }

    public func request(method: String, params: CodexJSONValue? = nil) async throws -> CodexJSONValue {
        guard process?.isRunning == true else {
            throw CodexError.processNotRunning
        }

        let id = nextRequestID
        nextRequestID += 1

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
                do {
                    try send(CodexJSONRPCRequest(method: method, id: id, params: params))
                } catch {
                    pending.removeValue(forKey: id)
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            Task { await self.cancelPendingRequest(id: id) }
        }
    }

    public func notify(method: String, params: CodexJSONValue? = nil) throws {
        guard process?.isRunning == true else {
            throw CodexError.processNotRunning
        }
        try send(CodexJSONRPCRequest(method: method, id: nil, params: params))
    }

    private func cancelPendingRequest(id: Int) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        continuation.resume(throwing: CodexError.cancelled)
    }

    private func send(_ message: CodexJSONRPCRequest) throws {
        guard let stdin else {
            throw CodexError.processNotRunning
        }

        var data = try JSONEncoder.codexRPC.encode(message)
        data.append(0x0A)
        try stdin.write(contentsOf: data)
    }

    private func send(_ message: CodexJSONRPCResponse) throws {
        guard let stdin else {
            throw CodexError.processNotRunning
        }

        var data = try JSONEncoder.codexRPC.encode(message)
        data.append(0x0A)
        try stdin.write(contentsOf: data)
    }

    private func startStdoutReader(fileHandle: FileHandle) {
        let wrappedFileHandle = CodexUncheckedSendable(fileHandle)
        stdoutReadTask = Task.detached(priority: .utility) { [wrappedFileHandle] in
            await Self.readLinesBlocking(from: wrappedFileHandle.value) { line in
                await self.handleStdoutLine(line)
            }
            await self.handleOutputClosed()
        }
    }

    private func startStderrReader(fileHandle: FileHandle) {
        let wrappedFileHandle = CodexUncheckedSendable(fileHandle)
        stderrReadTask = Task.detached(priority: .utility) { [wrappedFileHandle] in
            await Self.readLinesBlocking(from: wrappedFileHandle.value) { line in
                await self.handleStderrLine(line)
            }
        }
    }

    private nonisolated static func readLinesBlocking(
        from fileHandle: FileHandle,
        handleLine: @escaping @Sendable (String) async -> Void
    ) async {
        var buffer = Data()

        while !Task.isCancelled {
            let data = fileHandle.readData(ofLength: 4096)
            if data.isEmpty {
                break
            }

            for byte in data {
                if byte == 0x0A {
                    await emitLine(buffer, handleLine: handleLine)
                    buffer.removeAll(keepingCapacity: true)
                } else {
                    buffer.append(byte)
                }
            }
        }

        if !buffer.isEmpty {
            await emitLine(buffer, handleLine: handleLine)
        }
    }

    private nonisolated static func emitLine(
        _ data: Data,
        handleLine: @escaping @Sendable (String) async -> Void
    ) async {
        guard !data.isEmpty else { return }
        var line = String(decoding: data, as: UTF8.self)
        if line.last == "\r" {
            line.removeLast()
        }
        guard !line.isEmpty else { return }
        await handleLine(line)
    }

    private func handleStdoutLine(_ line: String) {
        do {
            let data = Data(line.utf8)
            let message = try JSONDecoder.codexRPC.decode(CodexJSONRPCIncomingMessage.self, from: data)
            try handle(message)
        } catch {
            diagnosticsBox.continuation.yield("Malformed app-server stdout: \(error.localizedDescription): \(line)")
        }
    }

    private func handleStderrLine(_ line: String) {
        diagnosticsBox.continuation.yield(line)
    }

    private func handle(_ message: CodexJSONRPCIncomingMessage) throws {
        if let id = message.id, message.result != nil || message.error != nil {
            guard let continuation = pending.removeValue(forKey: id) else {
                diagnosticsBox.continuation.yield("Received response for unknown request id \(id).")
                return
            }

            if let error = message.error {
                continuation.resume(throwing: CodexError.rpcError(code: error.code, message: error.message, data: error.data))
            } else {
                continuation.resume(returning: message.result ?? .null)
            }
            return
        }

        if let method = message.method, let id = message.id {
            diagnosticsBox.continuation.yield("Received unsupported server request '\(method)' with id \(id). Returning JSON-RPC Method not found.")
            let error = CodexJSONRPCError(code: -32601, message: "CodexAppServerKit does not implement server request '\(method)'.")
            try send(CodexJSONRPCResponse(id: id, result: nil, error: error))
            return
        }

        if let method = message.method {
            notificationsBox.continuation.yield(CodexNotification(method: method, params: message.params))
            return
        }

        diagnosticsBox.continuation.yield("Ignored app-server message without id or method: \(message)")
    }

    private func handleOutputClosed() {
        let status = process?.terminationStatus ?? -1
        process = nil
        stdin = nil
        failAllPending(with: CodexError.processExited(status: status))
    }

    private func failAllPending(with error: Error) {
        let continuations = pending.values
        pending.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }
}
