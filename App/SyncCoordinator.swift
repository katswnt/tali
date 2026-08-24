import Foundation
import HabitCore
import Observation
import SwiftData

@MainActor
@Observable
final class SyncStatus {
    var isSyncing = false
    var hasPendingChanges = false
    var lastSyncedAt: Date?
    var errorMessage: String?
}

@MainActor
enum SyncCoordinator {
    static let status = SyncStatus()

    private static var activeSync: Task<Void, Never>?
    private static var needsAnotherPass = false

    static func syncIfConfigured(context: ModelContext) async {
        guard !TaliDemoData.isEnabled else { return }
        guard SyncCredentials.isConfigured else { return }
        status.hasPendingChanges = true

        if let activeSync {
            needsAnotherPass = true
            await activeSync.value
            return
        }

        // Keep the shared sync alive if a view task is cancelled (for example,
        // when SwiftUI ends a pull-to-refresh or replaces the dashboard).
        let task = Task { @MainActor in
            defer {
                status.isSyncing = false
                activeSync = nil
            }

            repeat {
                needsAnotherPass = false
                status.isSyncing = true
                status.errorMessage = nil
                do {
                    _ = try await TaliSyncService.sync(
                        context: context,
                        endpoint: SyncCredentials.endpoint,
                        token: try await SyncCredentials.validAccessToken()
                    )
                    recordSuccess()
                } catch where error.isCancellation {
                    // View lifecycle cancellation is not a sync failure. Leave
                    // local changes pending so the next foreground sync retries.
                    status.errorMessage = nil
                    status.hasPendingChanges = true
                } catch {
                    recordFailure(error)
                }
            } while needsAnotherPass
        }
        activeSync = task
        await task.value
    }

    static func recordSuccess() {
        status.errorMessage = nil
        status.hasPendingChanges = false
        status.lastSyncedAt = .now
    }

    @discardableResult
    static func recordFailure(_ error: Error) -> Bool {
        guard !error.isCancellation else { return false }
        let authenticationExpired = SyncCredentials.invalidateIfNeeded(for: error)
        if authenticationExpired {
            status.errorMessage = "Your Tali session expired. Open Texting to sign in again."
        } else {
            status.errorMessage = error.localizedDescription
        }
        status.hasPendingChanges = true
        return authenticationExpired
    }
}

private extension Error {
    var isCancellation: Bool {
        if self is CancellationError {
            return true
        }
        return (self as? URLError)?.code == .cancelled
    }
}
