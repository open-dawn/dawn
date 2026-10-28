import Foundation

final class AskSession: @unchecked Sendable {
    private let lock = NSLock()
    private var fulfilled = false
    private var timeoutTask: Task<Void, Never>?
    private let continuation: CheckedContinuation<Event, Error>

    init(continuation: CheckedContinuation<Event, Error>) {
        self.continuation = continuation
    }

    func armTimeout(_ timeout: Duration) {
        let task = Task {
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }

            self.fail(with: EventAskError.timeout)
        }

        lock.withLock {
            timeoutTask = task
        }
    }

    func complete(with event: Event) {
        lock.withLock {
            cancelTimeoutLocked()
            guard !fulfilled else { return }
            fulfilled = true
            continuation.resume(returning: event)
        }
    }

    func fail(with error: Error) {
        lock.withLock {
            cancelTimeoutLocked()
            guard !fulfilled else { return }
            fulfilled = true
            continuation.resume(throwing: error)
        }
    }

    private func cancelTimeoutLocked() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}
