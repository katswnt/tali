import Foundation

/// Shares one in-progress asynchronous operation among all concurrent callers.
/// The completed value is not cached; a later caller starts a fresh operation.
@MainActor
public final class AsyncSingleFlight<Value: Sendable> {
    private var inFlight: Task<Value, Error>?
    private var inFlightID: UUID?

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
        let taskID = UUID()
        inFlight = task
        inFlightID = taskID

        do {
            let value = try await task.value
            clearIfCurrent(taskID)
            return value
        } catch {
            clearIfCurrent(taskID)
            throw error
        }
    }

    public func cancel() {
        inFlight?.cancel()
        inFlight = nil
        inFlightID = nil
    }

    private func clearIfCurrent(_ taskID: UUID) {
        guard inFlightID == taskID else { return }
        inFlight = nil
        inFlightID = nil
    }
}
