import HabitCore
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        DashboardView()
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await SyncCoordinator.syncIfConfigured(context: modelContext)
            }
    }
}
