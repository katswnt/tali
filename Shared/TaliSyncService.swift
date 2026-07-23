import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SwiftData

public struct TaliSyncReport: Sendable {
    public let habitCount: Int
    public let eventCount: Int
}

public enum TaliSyncError: LocalizedError {
    case invalidEndpoint
    case unauthorized
    case server(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Enter a valid HTTPS Worker URL."
        case .unauthorized:
            return "The sync token was rejected. Check that it matches your Worker secret."
        case .server(let message):
            return message
        case .invalidResponse:
            return "Tali received an invalid response from the sync service."
        }
    }
}

@MainActor
public enum TaliSyncService {
    public static func sync(
        context: ModelContext,
        endpoint: String,
        token: String,
        session: URLSession = .shared
    ) async throws -> TaliSyncReport {
        let url = try syncURL(from: endpoint)
        try consolidateLocalHabits(in: context)
        let localHabits = try context.fetch(FetchDescriptor<Habit>())
        let localEvents = try context.fetch(FetchDescriptor<HabitEvent>())
        let snapshot = SyncSnapshot(
            habits: localHabits.map(SyncHabit.init),
            events: localEvents.compactMap(SyncEvent.init)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(snapshot)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TaliSyncError.invalidResponse
        }
        if httpResponse.statusCode == 401 { throw TaliSyncError.unauthorized }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ServerError.self, from: data).error)
                ?? "The sync service returned HTTP \(httpResponse.statusCode)."
            throw TaliSyncError.server(message)
        }

        let remote = try decoder.decode(SyncSnapshot.self, from: data)
        try merge(remote, into: context)
        return TaliSyncReport(habitCount: remote.habits.count, eventCount: remote.events.count)
    }

    private static func syncURL(from endpoint: String) throws -> URL {
        let value = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: value),
              components.scheme == "https",
              components.host != nil else {
            throw TaliSyncError.invalidEndpoint
        }
        if !components.path.hasSuffix("/v1/sync") {
            components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/" + ([components.path, "v1/sync"]
                .filter { !$0.isEmpty && $0 != "/" }
                .joined(separator: "/"))
        }
        guard let url = components.url else { throw TaliSyncError.invalidEndpoint }
        return url
    }

    private static func merge(_ snapshot: SyncSnapshot, into context: ModelContext) throws {
        try consolidateLocalHabits(in: context)
        let localHabits = try context.fetch(FetchDescriptor<Habit>())
        var habitsByID = Dictionary(uniqueKeysWithValues: localHabits.map { ($0.id, $0) })
        var habitsByName = Dictionary(uniqueKeysWithValues: localHabits.map { ($0.normalizedName, $0) })

        for remote in snapshot.habits {
            let normalizedName = Habit.normalize(remote.name)
            if let exact = habitsByID[remote.id] {
                guard remote.updatedAt > exact.updatedAt else {
                    habitsByName[exact.normalizedName] = exact
                    continue
                }
                habitsByName.removeValue(forKey: exact.normalizedName)
                apply(remote, normalizedName: normalizedName, to: exact)
                habitsByName[exact.normalizedName] = exact
            } else if let sameName = habitsByName[normalizedName] {
                habitsByID.removeValue(forKey: sameName.id)
                let habit = replacingIdentity(of: sameName, with: remote.id, in: context)
                habitsByID[remote.id] = habit
                habitsByName[normalizedName] = habit
                apply(remote, normalizedName: normalizedName, to: habit)
            } else {
                let habit = Habit(
                    id: remote.id,
                    name: remote.name,
                    aliases: remote.aliases,
                    createdAt: remote.createdAt,
                    isArchived: remote.isArchived
                )
                habit.updatedAt = remote.updatedAt
                context.insert(habit)
                habitsByID[habit.id] = habit
                habitsByName[habit.normalizedName] = habit
            }
        }

        let localEvents = try context.fetch(FetchDescriptor<HabitEvent>())
        let eventsByID = Dictionary(uniqueKeysWithValues: localEvents.map { ($0.id, $0) })
        for remote in snapshot.events {
            guard let habit = habitsByID[remote.habitId] else { continue }
            if let event = eventsByID[remote.id] {
                guard remote.updatedAt > event.updatedAt else { continue }
                event.occurredAt = remote.occurredAt
                event.createdAt = remote.createdAt
                event.sourceRawValue = remote.source
                event.note = remote.note
                event.voidedAt = remote.voidedAt
                event.habit = habit
                event.updatedAt = remote.updatedAt
            } else {
                let event = HabitEvent(
                    id: remote.id,
                    occurredAt: remote.occurredAt,
                    createdAt: remote.createdAt,
                    source: HabitEventSource(rawValue: remote.source) ?? .sms,
                    note: remote.note,
                    habit: habit
                )
                event.voidedAt = remote.voidedAt
                event.updatedAt = remote.updatedAt
                context.insert(event)
            }
        }
        try context.save()
        try consolidateLocalHabits(in: context)
    }

    private static func apply(
        _ remote: SyncHabit,
        normalizedName: String,
        to habit: Habit
    ) {
        habit.name = remote.name
        habit.normalizedName = normalizedName
        habit.aliases = remote.aliases
        habit.createdAt = remote.createdAt
        habit.isArchived = remote.isArchived
        habit.updatedAt = remote.updatedAt
    }

    static func replacingIdentity(
        of habit: Habit,
        with id: UUID,
        in context: ModelContext
    ) -> Habit {
        let replacement = Habit(
            id: id,
            name: habit.name,
            aliases: habit.aliases,
            createdAt: habit.createdAt,
            isArchived: habit.isArchived
        )
        replacement.updatedAt = habit.updatedAt
        context.insert(replacement)
        for event in habit.events {
            event.habit = replacement
        }
        context.delete(habit)
        return replacement
    }

    static func consolidateLocalHabits(in context: ModelContext) throws {
        let habits = try context.fetch(FetchDescriptor<Habit>()).sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        var canonicalByName: [String: Habit] = [:]
        var changed = false

        for habit in habits {
            let key = Habit.normalize(habit.name)
            guard let canonical = canonicalByName[key] else {
                canonicalByName[key] = habit
                continue
            }

            let aliases = Array(Set(canonical.aliases + habit.aliases)).sorted()
            canonical.aliases = aliases
            if habit.updatedAt > canonical.updatedAt {
                canonical.name = habit.name
                canonical.normalizedName = key
                canonical.isArchived = habit.isArchived
                canonical.updatedAt = habit.updatedAt
            }
            canonical.createdAt = min(canonical.createdAt, habit.createdAt)
            for event in habit.events {
                event.habit = canonical
            }
            context.delete(habit)
            changed = true
        }

        if changed { try context.save() }
    }

    nonisolated static func encodedTimestamp(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(encodedTimestamp(date))
        }
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(value, strategy: .iso8601) { return date }
            if let date = ISO8601DateFormatter().date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        return decoder
    }()
}

private struct SyncSnapshot: Codable {
    let habits: [SyncHabit]
    let events: [SyncEvent]
}

private struct SyncHabit: Codable {
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

private struct SyncEvent: Codable {
    let id: UUID
    let habitId: UUID
    let occurredAt: Date
    let createdAt: Date
    let updatedAt: Date
    let source: String
    let note: String?
    let voidedAt: Date?

    init?(_ event: HabitEvent) {
        guard let habitId = event.habit?.id else { return nil }
        id = event.id
        self.habitId = habitId
        occurredAt = event.occurredAt
        createdAt = event.createdAt
        updatedAt = event.updatedAt
        source = event.sourceRawValue
        note = event.note
        voidedAt = event.voidedAt
    }
}

private struct ServerError: Decodable {
    let error: String
}
