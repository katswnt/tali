import AppIntents
import HabitCore
import SwiftData

public struct LogHabitIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log a Habit"
    public static let description = IntentDescription("Adds a dated habit entry in Tali.")
    public static let isDiscoverable = true

    @Parameter(title: "Habit")
    public var habitName: String

    @Parameter(title: "When", default: .now)
    public var occurredAt: Date

    public static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$habitName) in Tali") {
            \.$occurredAt
        }
    }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try PersistenceController.makeContainer()
        let engine = HabitEngine(context: container.mainContext)
        let habit = try engine.resolveHabit(habitName)
        let result = try engine.log(habit: habit, at: occurredAt, source: .shortcut)

        let previous = result.previousEvent.map {
            " Previous: \(HabitFormatting.elapsed(from: $0.occurredAt, to: occurredAt))."
        } ?? " No earlier entries."
        return .result(dialog: "Logged \(habit.name).\(previous)")
    }
}

public enum TaliShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogHabitIntent(),
            phrases: [
                "Log a habit in \(.applicationName)",
                "Record a habit in \(.applicationName)"
            ],
            shortTitle: "Log Habit",
            systemImageName: "plus.circle"
        )
    }

    public static var shortcutTileColor: ShortcutTileColor {
        .lime
    }
}
