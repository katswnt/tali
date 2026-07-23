import Foundation
import SwiftData

public enum HabitEventSource: String, Codable, CaseIterable {
    case app
    case messages
    case shortcut
    case sms
}

@Model
public final class Habit {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var normalizedName: String
    public var aliasesText: String
    public var createdAt: Date
    public var updatedAt: Date = Date.now
    public var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \HabitEvent.habit)
    public var events: [HabitEvent]

    public init(
        id: UUID = UUID(),
        name: String,
        aliases: [String] = [],
        createdAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedName = Habit.normalize(name)
        self.aliasesText = aliases
            .map(Habit.normalize)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isArchived = isArchived
        self.events = []
    }

    public var aliases: [String] {
        get { aliasesText.split(separator: "\n").map(String.init) }
        set {
            aliasesText = newValue
                .map(Habit.normalize)
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }

    public var searchTerms: [String] {
        [normalizedName] + aliases
    }

    public static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

@Model
public final class HabitEvent {
    @Attribute(.unique) public var id: UUID
    public var occurredAt: Date
    public var createdAt: Date
    public var sourceRawValue: String
    public var note: String?
    public var voidedAt: Date?
    public var updatedAt: Date = Date.now
    public var habit: Habit?

    public init(
        id: UUID = UUID(),
        occurredAt: Date = .now,
        createdAt: Date = .now,
        source: HabitEventSource,
        note: String? = nil,
        habit: Habit
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.sourceRawValue = source.rawValue
        self.note = note
        self.voidedAt = nil
        self.updatedAt = createdAt
        self.habit = habit
    }

    public var source: HabitEventSource {
        HabitEventSource(rawValue: sourceRawValue) ?? .app
    }

    public var isVoided: Bool {
        voidedAt != nil
    }
}
