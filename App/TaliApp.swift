import AppIntents
import HabitCore
import SwiftData
import SwiftUI

@main
struct TaliApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        TaliShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            StoreBootstrapView()
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        TaliShortcuts.updateAppShortcutParameters()
                        Task { await updateServerTimeZone() }
                    }
                }
        }
    }

    @MainActor
    private func updateServerTimeZone() async {
        guard SyncCredentials.isConfigured else { return }
        do {
            try await TaliAccountService.updateTimeZone(
                endpoint: SyncCredentials.endpoint,
                token: try await SyncCredentials.validAccessToken()
            )
        } catch {
            // This is a best-effort foreground refresh. The next activation or
            // full sync will retry without interrupting the user.
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
            let openedContainer = try PersistenceController.makeContainer(
                inMemory: TaliDemoData.isEnabled || TaliTestEnvironment.isUITesting
            )
            TaliTestEnvironment.prepare()
            if TaliDemoData.isEnabled {
                try TaliDemoData.seed(openedContainer)
            }
            container = openedContainer
        } catch {
            errorMessage = error.localizedDescription
        }
        isOpening = false
    }
}

enum TaliTestEnvironment {
    static var isUITesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-tali-ui-test")
        #else
        false
        #endif
    }

    @MainActor
    static func prepare() {
        guard isUITesting else { return }
        let keys = [
            TimeSinceVisibility.globalPreferenceKey,
            TimeSinceVisibility.hiddenHabitIDsPreferenceKey,
            SyncCredentials.endpointKey,
        ]
        for defaults in [
            UserDefaults.standard,
            UserDefaults(suiteName: PersistenceController.appGroupIdentifier),
        ].compactMap({ $0 }) {
            for key in keys {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

enum TaliDemoData {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-tali-demo")
        #else
        false
        #endif
    }

    @MainActor
    static func seed(_ container: ModelContainer, now: Date = .now) throws {
        guard isEnabled else { return }

        let context = container.mainContext
        let engine = HabitEngine(context: context)
        let yoga = try engine.addHabit(name: "Yoga")
        let weed = try engine.addHabit(name: "Weed")
        let physicalTherapy = try engine.addHabit(
            name: "Physical therapy",
            aliases: ["pt"]
        )
        let callMom = try engine.addHabit(name: "Call Mom")

        for day in [1, 3, 6, 7, 10, 15, 22, 28, 30, 42, 45, 60, 75, 80] {
            try engine.log(habit: yoga, at: demoDate(daysAgo: day, hour: 8, now: now), source: .app)
        }
        for day in [4, 11, 19, 33, 47, 65] {
            try engine.log(habit: weed, at: demoDate(daysAgo: day, hour: 20, now: now), source: .sms)
        }
        for day in [2, 9, 16, 23, 30] {
            try engine.log(
                habit: physicalTherapy,
                at: demoDate(daysAgo: day, hour: 17, now: now),
                source: .messages
            )
        }
        for day in [5, 18, 37, 58] {
            try engine.log(habit: callMom, at: demoDate(daysAgo: day, hour: 19, now: now), source: .shortcut)
        }
    }

    private static func demoDate(daysAgo: Int, hour: Int, now: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }
}
