import Foundation
import SwiftData

public struct HabitLogResult {
    public let habit: Habit
    public let event: HabitEvent
    public let previousEvent: HabitEvent?
}

public enum HabitEngineError: LocalizedError, Equatable {
    case invalidHabitName
    case invalidHabitTerm(String)
    case tooManyAliases
    case noteTooLong
    case futureEvent
    case habitAlreadyExists(String)
    case habitNotFound(String)
    case ambiguousHabit(String)
    case typoSuggestion(query: String, suggestion: String, canCreate: Bool)
    case noEventToUndo
    case unsupportedCommand

    public var errorDescription: String? {
        switch self {
        case .invalidHabitName:
            return "Enter a habit name."
        case .invalidHabitTerm(let message):
            return message
        case .tooManyAliases:
            return "Use no more than \(HabitInputRules.maximumAliasCount) aliases."
        case .noteTooLong:
            return "Notes must be \(HabitInputRules.maximumNoteLength) characters or fewer."
        case .futureEvent:
            return "That time is in the future, so nothing was logged."
        case .habitAlreadyExists(let name):
            return "“\(name)” already uses that name or alias."
        case .habitNotFound(let query):
            return "I couldn't find “\(query)”. To create it, text “add habit \(query)”."
        case .ambiguousHabit(let query):
            return "“\(query)” matches more than one habit. Try the full name."
        case .typoSuggestion(let query, let suggestion, let canCreate):
            if canCreate {
                return "Did you mean “\(suggestion)”? Text “\(suggestion)” to log it, "
                    + "or “add habit \(query) anyway” to create a new habit."
            }
            return "Did you mean “\(suggestion)”?"
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
        let cleanedAliases = HabitInputRules.normalizedUniqueAliases(aliases)
        try validate(name: name, aliases: cleanedAliases)
        let habit = Habit(name: name, aliases: cleanedAliases)
        context.insert(habit)
        try context.save()
        return habit
    }

    public func updateHabit(_ habit: Habit, name: String, aliases: [String]) throws {
        let cleanedAliases = HabitInputRules.normalizedUniqueAliases(aliases)
        try validate(name: name, aliases: cleanedAliases, excluding: habit)
        habit.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.normalizedName = Habit.normalize(name)
        habit.aliases = cleanedAliases
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
        if let suggestion = suggestedHabit(for: query, among: available) {
            throw HabitEngineError.typoSuggestion(
                query: query,
                suggestion: suggestion.name,
                canCreate: false
            )
        }
        throw HabitEngineError.habitNotFound(query)
    }

    @discardableResult
    public func log(
        habit: Habit,
        at date: Date = .now,
        source: HabitEventSource,
        note: String? = nil
    ) throws -> HabitLogResult {
        guard date.timeIntervalSinceNow <= 5 * 60 else {
            throw HabitEngineError.futureEvent
        }
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmedNote?.count ?? 0) <= HabitInputRules.maximumNoteLength else {
            throw HabitEngineError.noteTooLong
        }
        let previous = activeEvents(for: habit, before: date).first
        let event = HabitEvent(
            occurredAt: date,
            source: source,
            note: trimmedNote?.isEmpty == false ? trimmedNote : nil,
            habit: habit
        )
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

    public func updateEvent(
        _ event: HabitEvent,
        at date: Date,
        note: String?
    ) throws {
        guard date.timeIntervalSinceNow <= 5 * 60 else {
            throw HabitEngineError.futureEvent
        }
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmedNote?.count ?? 0) <= HabitInputRules.maximumNoteLength else {
            throw HabitEngineError.noteTooLong
        }

        event.occurredAt = date
        event.note = trimmedNote?.isEmpty == false ? trimmedNote : nil
        event.updatedAt = .now
        try context.save()
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
        case .add(let name, let force):
            if !force, let suggestion = suggestedHabit(for: name, among: try habits()) {
                throw HabitEngineError.typoSuggestion(
                    query: name,
                    suggestion: suggestion.name,
                    canCreate: true
                )
            }
            return .added(try addHabit(name: name))
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
        case .invalid(let message):
            throw HabitEngineError.invalidHabitTerm(message)
        case .contact, .help:
            throw HabitEngineError.unsupportedCommand
        }
    }

    private func validate(name: String, aliases: [String], excluding excludedHabit: Habit? = nil) throws {
        let normalizedName = Habit.normalize(name)
        guard !normalizedName.isEmpty else { throw HabitEngineError.invalidHabitName }
        if let message = HabitInputRules.validationMessage(for: name, label: "Habit names") {
            throw HabitEngineError.invalidHabitTerm(message)
        }
        guard aliases.count <= HabitInputRules.maximumAliasCount else {
            throw HabitEngineError.tooManyAliases
        }
        let uniqueAliases = HabitInputRules.normalizedUniqueAliases(aliases)
        let allowedLogTargets = Set([normalizedName] + uniqueAliases.map(Habit.normalize))
        for alias in uniqueAliases {
            if let message = HabitInputRules.validationMessage(
                for: alias,
                label: "Aliases",
                allowedLogTargets: allowedLogTargets
            ) {
                throw HabitEngineError.invalidHabitTerm(message)
            }
            guard alias.count <= HabitInputRules.maximumAliasLength else {
                throw HabitEngineError.invalidHabitTerm(
                    "Aliases must be \(HabitInputRules.maximumAliasLength) characters or fewer."
                )
            }
        }

        let candidateTerms = Set(([normalizedName] + uniqueAliases.map(Habit.normalize)).filter { !$0.isEmpty })
        let conflict = try habits(includeArchived: true).first { habit in
            habit.id != excludedHabit?.id && !candidateTerms.isDisjoint(with: Set(habit.searchTerms))
        }
        if let conflict { throw HabitEngineError.habitAlreadyExists(conflict.name) }
    }

    private func suggestedHabit(for query: String, among habits: [Habit]) -> Habit? {
        let normalized = Habit.normalize(query)
        guard normalized.count >= 3 else { return nil }
        let maximumDistance = normalized.count <= 4 ? 1 : normalized.count <= 8 ? 2 : 3
        let ranked = habits.compactMap { habit -> (habit: Habit, distance: Int)? in
            let distance = habit.searchTerms
                .map { editDistance(normalized, $0) }
                .min() ?? Int.max
            guard distance > 0, distance <= maximumDistance else { return nil }
            return (habit, distance)
        }
        .sorted { $0.distance < $1.distance }
        guard let first = ranked.first else { return nil }
        guard ranked.dropFirst().first?.distance != first.distance else { return nil }
        return first.habit
    }

    private func editDistance(_ left: String, _ right: String) -> Int {
        let source = Array(left)
        let target = Array(right)
        var matrix = (0...source.count).map { row in
            (0...target.count).map { column in row == 0 ? column : 0 }
        }
        for row in 1...source.count {
            matrix[row][0] = row
            for column in 1...target.count {
                let substitution = matrix[row - 1][column - 1]
                    + (source[row - 1] == target[column - 1] ? 0 : 1)
                matrix[row][column] = min(
                    matrix[row - 1][column] + 1,
                    matrix[row][column - 1] + 1,
                    substitution
                )
                if row > 1,
                   column > 1,
                   source[row - 1] == target[column - 2],
                   source[row - 2] == target[column - 1] {
                    matrix[row][column] = min(
                        matrix[row][column],
                        matrix[row - 2][column - 2] + 1
                    )
                }
            }
        }
        return matrix[source.count][target.count]
    }
}

public enum HabitResponse {
    case logged(HabitLogResult)
    case added(Habit)
    case since(habit: Habit, event: HabitEvent?)
    case history(habit: Habit, events: [HabitEvent])
    case undone(HabitEvent)
    case habits([Habit])
}
