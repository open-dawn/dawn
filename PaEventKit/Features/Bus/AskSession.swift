import Foundation

final class AskSession: @unchecked Sendable {
    private let lock = NSLock()
    private var fulfilled = false
    private let continuation: CheckedContinuation<PaEvent, Error>

    init(continuation: CheckedContinuation<PaEvent, Error>) {
        self.continuation = continuation
    }

    func complete(with event: PaEvent) {
        lock.withLock {
            guard !fulfilled else { return }
            fulfilled = true
            continuation.resume(returning: event)
        }
    }

    func fail(with error: Error) {
        lock.withLock {
            guard !fulfilled else { return }
            fulfilled = true
            continuation.resume(throwing: error)
        }
    }
}
