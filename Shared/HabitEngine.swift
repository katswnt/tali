import Foundation
import SwiftData

public struct HabitLogResult {
    public let habit: Habit
    public let event: HabitEvent
    public let previousEvent: HabitEvent?
}

public enum HabitEngineError: LocalizedError, Equatable {
    case invalidHabitName
    case habitAlreadyExists(String)
    case habitNotFound(String)
    case ambiguousHabit(String)
    case noEventToUndo
    case unsupportedCommand

    public var errorDescription: String? {
        switch self {
        case .invalidHabitName:
            return "Enter a habit name."
        case .habitAlreadyExists(let name):
            return "“\(name)” already uses that name or alias."
        case .habitNotFound(let query):
            return "I couldn't find “\(query)”. Add it in Tali first."
        case .ambiguousHabit(let query):
            return "“\(query)” matches more than one habit. Try the full name."
        case .noEventToUndo:
            return "There isn't a recent log to undo."
        case .unsupportedCommand:
            return "Try a habit name, “time since yoga,” “habits,” or “undo.”"
        }
    }
}

@MainActor
public struct HabitEngine {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func habits(includeArchived: Bool = false) throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\Habit.name)])
        let values = try context.fetch(descriptor)
        return includeArchived ? values : values.filter { !$0.isArchived }
    }

    @discardableResult
    public func addHabit(name: String, aliases: [String] = []) throws -> Habit {
        try validate(name: name, aliases: aliases)
        let habit = Habit(name: name, aliases: aliases)
        context.insert(habit)
        try context.save()
        return habit
    }

    public func updateHabit(_ habit: Habit, name: String, aliases: [String]) throws {
        try validate(name: name, aliases: aliases, excluding: habit)
        habit.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.normalizedName = Habit.normalize(name)
        habit.aliases = aliases
        habit.updatedAt = .now
        try context.save()
    }

    public func setArchived(_ habit: Habit, _ isArchived: Bool) throws {
        habit.isArchived = isArchived
        habit.updatedAt = .now
        try context.save()
    }

    public func resolveHabit(_ query: String) throws -> Habit {
        let normalized = Habit.normalize(query)
        let available = try habits()
        let exact = available.filter { $0.searchTerms.contains(normalized) }
        if exact.count == 1, let match = exact.first { return match }
        if exact.count > 1 { throw HabitEngineError.ambiguousHabit(query) }

        let partial = available.filter { habit in
            habit.searchTerms.contains { $0.hasPrefix(normalized) || normalized.hasPrefix($0) }
        }
        if partial.count == 1, let match = partial.first { return match }
        if partial.count > 1 { throw HabitEngineError.ambiguousHabit(query) }
        throw HabitEngineError.habitNotFound(query)
    }

    @discardableResult
    public func log(
        habit: Habit,
        at date: Date = .now,
        source: HabitEventSource,
        note: String? = nil
    ) throws -> HabitLogResult {
        let previous = activeEvents(for: habit, before: date).first
        let event = HabitEvent(occurredAt: date, source: source, note: note, habit: habit)
        context.insert(event)
        try context.save()
        return HabitLogResult(habit: habit, event: event, previousEvent: previous)
    }

    public func activeEvents(for habit: Habit, before date: Date? = nil) -> [HabitEvent] {
        habit.events
            .filter { event in
                !event.isVoided && (date.map { event.occurredAt < $0 } ?? true)
            }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    public func latestEvent(for habit: Habit) -> HabitEvent? {
        activeEvents(for: habit).first
    }

    @discardableResult
    public func undoLatest() throws -> HabitEvent {
        let all = try habits(includeArchived: true)
            .flatMap { activeEvents(for: $0) }
            .sorted { $0.createdAt > $1.createdAt }
        guard let latest = all.first else { throw HabitEngineError.noEventToUndo }
        latest.voidedAt = .now
        latest.updatedAt = .now
        try context.save()
        return latest
    }

    public func execute(
        _ command: HabitCommand,
        source: HabitEventSource,
        defaultDate: Date = .now
    ) throws -> HabitResponse {
        switch command {
        case .log(let query, let date, let note):
            let habit = try resolveHabit(query)
            let result = try log(habit: habit, at: date ?? defaultDate, source: source, note: note)
            return .logged(result)
        case .since(let query):
            let habit = try resolveHabit(query)
            return .since(habit: habit, event: latestEvent(for: habit))
        case .history(let query):
            let habit = try resolveHabit(query)
            return .history(habit: habit, events: Array(activeEvents(for: habit).prefix(10)))
        case .undo:
            return .undone(try undoLatest())
        case .list:
            return .habits(try habits())
        case .contact, .help, .unknown:
            throw HabitEngineError.unsupportedCommand
        }
    }

    private func validate(name: String, aliases: [String], excluding excludedHabit: Habit? = nil) throws {
        let normalizedName = Habit.normalize(name)
        guard !normalizedName.isEmpty else { throw HabitEngineError.invalidHabitName }

        let candidateTerms = Set(([normalizedName] + aliases.map(Habit.normalize)).filter { !$0.isEmpty })
        let conflict = try habits(includeArchived: true).first { habit in
            habit.id != excludedHabit?.id && !candidateTerms.isDisjoint(with: Set(habit.searchTerms))
        }
        if let conflict { throw HabitEngineError.habitAlreadyExists(conflict.name) }
    }
}

public enum HabitResponse {
    case logged(HabitLogResult)
    case since(habit: Habit, event: HabitEvent?)
    case history(habit: Habit, events: [HabitEvent])
    case undone(HabitEvent)
    case habits([Habit])
}
