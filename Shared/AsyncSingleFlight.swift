import Foundation

/// Shares one in-progress asynchronous operation among all concurrent callers.
/// The completed value is not cached; a later caller starts a fresh operation.
@MainActor
public final class AsyncSingleFlight<Value: Sendable> {
    private var inFlight: Task<Value, Error>?

    public init() {}

    public func run(
        _ operation: @escaping @MainActor @Sendable () async throws -> Value
    ) async throws -> Value {
        if let inFlight {
            return try await inFlight.value
        }

        let task = Task { @MainActor in
            try await operation()
        }
        inFlight = task

        do {
            let value = try await task.value
            inFlight = nil
            return value
        } catch {
            inFlight = nil
            throw error
        }
    }
}
