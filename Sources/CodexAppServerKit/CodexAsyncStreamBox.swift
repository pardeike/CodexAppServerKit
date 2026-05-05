import Foundation

final class CodexAsyncStreamBox<Element: Sendable>: @unchecked Sendable {
    let stream: AsyncStream<Element>
    let continuation: AsyncStream<Element>.Continuation

    init(bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded) {
        let pair = AsyncStream<Element>.makeStream(of: Element.self, bufferingPolicy: bufferingPolicy)
        stream = pair.stream
        continuation = pair.continuation
    }
}

struct CodexUncheckedSendable<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
