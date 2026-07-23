import Foundation

public enum TaliDataExport {
    public static func csv(
        habits: [Habit],
        events: [HabitEvent],
        exportedAt: Date = .now
    ) -> Data {
        let header = [
            "record_type",
            "habit_id",
            "habit_name",
            "habit_aliases",
            "habit_archived",
            "habit_created_at",
            "habit_updated_at",
            "entry_id",
            "occurred_at",
            "entry_created_at",
            "entry_updated_at",
            "source",
            "note",
            "voided_at",
        ]
        var rows = [header]

        for habit in sortedHabits(habits) {
            rows.append([
                "habit",
                habit.id.uuidString,
                habit.name,
                habit.aliases.joined(separator: " | "),
                String(habit.isArchived),
                timestamp(habit.createdAt),
                timestamp(habit.updatedAt),
                "", "", "", "", "", "", "",
            ])
        }

        for event in sortedEvents(events) {
            let habit = event.habit
            rows.append([
                "entry",
                habit?.id.uuidString ?? "",
                habit?.name ?? "",
                habit?.aliases.joined(separator: " | ") ?? "",
                habit.map { String($0.isArchived) } ?? "",
                habit.map { timestamp($0.createdAt) } ?? "",
                habit.map { timestamp($0.updatedAt) } ?? "",
                event.id.uuidString,
                timestamp(event.occurredAt),
                timestamp(event.createdAt),
                timestamp(event.updatedAt),
                event.sourceRawValue,
                event.note ?? "",
                event.voidedAt.map(timestamp) ?? "",
            ])
        }

        let contents = rows
            .map { $0.map(csvField).joined(separator: ",") }
            .joined(separator: "\r\n")
        // The UTF-8 BOM keeps names and notes legible when opened directly in Excel.
        return Data(("\u{FEFF}" + contents + "\r\n").utf8)
    }

    public static func json(
        habits: [Habit],
        events: [HabitEvent],
        exportedAt: Date = .now
    ) throws -> Data {
        let archive = Archive(
            schemaVersion: 1,
            exportedAt: exportedAt,
            habits: sortedHabits(habits).map(HabitRecord.init),
            entries: sortedEvents(events).map(EntryRecord.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(timestamp(date))
        }
        return try encoder.encode(archive)
    }

    private static func sortedHabits(_ habits: [Habit]) -> [Habit] {
        habits.sorted {
            if $0.normalizedName != $1.normalizedName { return $0.normalizedName < $1.normalizedName }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private static func sortedEvents(_ events: [HabitEvent]) -> [HabitEvent] {
        events.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private static func timestamp(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

private extension TaliDataExport {
    struct Archive: Codable {
        let schemaVersion: Int
        let exportedAt: Date
        let habits: [HabitRecord]
        let entries: [EntryRecord]
    }

    struct HabitRecord: Codable {
        let id: UUID
        let name: String
        let aliases: [String]
        let createdAt: Date
        let updatedAt: Date
        let isArchived: Bool

        init(_ habit: Habit) {
            id = habit.id
            name = habit.name
            aliases = habit.aliases
            createdAt = habit.createdAt
            updatedAt = habit.updatedAt
            isArchived = habit.isArchived
        }
    }

    struct EntryRecord: Codable {
        let id: UUID
        let habitId: UUID?
        let occurredAt: Date
        let createdAt: Date
        let updatedAt: Date
        let source: String
        let note: String?
        let voidedAt: Date?

        init(_ event: HabitEvent) {
            id = event.id
            habitId = event.habit?.id
            occurredAt = event.occurredAt
            createdAt = event.createdAt
            updatedAt = event.updatedAt
            source = event.sourceRawValue
            note = event.note
            voidedAt = event.voidedAt
        }
    }
}
