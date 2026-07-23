import AppIntents
import HabitCore
import SwiftData

struct LogHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Habit"
    static let description = IntentDescription("Adds a dated habit entry in Tali.")

    @Parameter(title: "Habit")
    var habitName: String

    @Parameter(title: "When", default: .now)
    var occurredAt: Date

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
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

struct TaliShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
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
}
