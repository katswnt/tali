import HabitCore
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DashboardView()
            .task {
                await SyncCoordinator.syncIfConfigured(context: modelContext)
            }
    }
}
