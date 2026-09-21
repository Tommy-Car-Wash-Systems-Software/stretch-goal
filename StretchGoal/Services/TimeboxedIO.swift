import Foundation

/// File reads against a cloud-backed folder can block while the File Provider fetches a
/// placeholder. Every read gets a deadline; a late result is dropped.
enum TimeboxedIO {
    private static let queue = DispatchQueue(label: "com.tommycarwash.StretchGoal.io", attributes: .concurrent)

    static func read(_ url: URL, timeout: Duration) async -> Data? {
        await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            queue.async { once.resume(try? Data(contentsOf: url)) }
            Task {
                try? await Task.sleep(for: timeout)
                once.resume(nil)
            }
        }
    }

    private final class ResumeOnce: @unchecked Sendable {
        private var continuation: CheckedContinuation<Data?, Never>?
        private let lock = NSLock()

        init(_ continuation: CheckedContinuation<Data?, Never>) {
            self.continuation = continuation
        }

        func resume(_ value: Data?) {
            lock.lock()
            let c = continuation
            continuation = nil
            lock.unlock()
            c?.resume(returning: value)
        }
    }
}
