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

    private static var isRunning = false
    private static var needsAnotherPass = false

    static func syncIfConfigured(context: ModelContext) async {
        guard SyncCredentials.isConfigured else { return }
        status.hasPendingChanges = true

        if isRunning {
            needsAnotherPass = true
            return
        }

        isRunning = true
        repeat {
            needsAnotherPass = false
            status.isSyncing = true
            status.errorMessage = nil
            do {
                _ = try await TaliSyncService.sync(
                    context: context,
                    endpoint: SyncCredentials.endpoint,
                    token: SyncCredentials.token()
                )
                recordSuccess()
            } catch {
                recordFailure(error)
            }
        } while needsAnotherPass
        status.isSyncing = false
        isRunning = false
    }

    static func recordSuccess() {
        status.errorMessage = nil
        status.hasPendingChanges = false
        status.lastSyncedAt = .now
    }

    static func recordFailure(_ error: Error) {
        status.errorMessage = error.localizedDescription
        status.hasPendingChanges = true
    }
}
