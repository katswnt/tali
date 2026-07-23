import HabitCore
import SwiftData
import SwiftUI

@main
struct TaliApp: App {
    var body: some Scene {
        WindowGroup {
            StoreBootstrapView()
        }
    }
}

private struct StoreBootstrapView: View {
    @State private var container: ModelContainer?
    @State private var errorMessage: String?
    @State private var isOpening = false

    var body: some View {
        Group {
            if let container {
                RootView()
                    .modelContainer(container)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Tali couldn’t open its data", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try again") {
                        openStore()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView("Opening Tali…")
            }
        }
        .task {
            if container == nil && errorMessage == nil {
                openStore()
            }
        }
    }

    private func openStore() {
        guard !isOpening else { return }
        isOpening = true
        errorMessage = nil
        do {
            container = try PersistenceController.makeContainer()
        } catch {
            errorMessage = error.localizedDescription
        }
        isOpening = false
    }
}
