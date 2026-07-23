import Foundation
import SwiftData
import Testing
@testable import HabitCore

@MainActor
struct HabitEngineTests {
    @Test("User-defined aliases resolve")
    func resolvesAliases() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let engine = HabitEngine(context: container.mainContext)

        _ = try engine.addHabit(
            name: "Physical therapy",
            aliases: ["pt", "exercises"]
        )

        #expect(try engine.habits().count == 1)
        #expect(try engine.resolveHabit("pt").name == "Physical therapy")
    }

    @Test("Logging returns the prior event and undo voids the newest log")
    func logsAndUndoes() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let engine = HabitEngine(context: container.mainContext)
        let habit = try engine.addHabit(name: "Read")
        let firstDate = Date(timeIntervalSince1970: 100)
        let secondDate = Date(timeIntervalSince1970: 200)

        _ = try engine.log(habit: habit, at: firstDate, source: .app)
        let second = try engine.log(habit: habit, at: secondDate, source: .messages)

        #expect(second.previousEvent?.occurredAt == firstDate)
        #expect(engine.activeEvents(for: habit).count == 2)

        let undone = try engine.undoLatest()
        #expect(undone.occurredAt == secondDate)
        #expect(engine.activeEvents(for: habit).count == 1)
    }

    @Test("Unknown habits produce a useful error")
    func rejectsUnknownHabit() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let engine = HabitEngine(context: container.mainContext)
        _ = try engine.addHabit(name: "Yoga")

        #expect(throws: HabitEngineError.habitNotFound("run")) {
            try engine.resolveHabit("run")
        }
    }

    @Test("Duplicate habits consolidate without losing events or aliases")
    func consolidatesDuplicateHabits() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let first = Habit(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            name: "Meditate",
            aliases: ["meditation"],
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let duplicate = Habit(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            name: " meditate ",
            aliases: ["meditated"],
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let event = HabitEvent(
            occurredAt: Date(timeIntervalSince1970: 300),
            source: .sms,
            habit: duplicate
        )
        context.insert(first)
        context.insert(duplicate)
        context.insert(event)
        try context.save()

        try TaliSyncService.consolidateLocalHabits(in: context)

        let habits = try context.fetch(FetchDescriptor<Habit>())
        #expect(habits.count == 1)
        #expect(Set(habits[0].aliases) == Set(["meditation", "meditated"]))
        #expect(habits[0].events.count == 1)
        #expect(habits[0].events[0].id == event.id)
    }

    @Test("Habit names and aliases stay unique across edits")
    func validatesHabitIdentity() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let engine = HabitEngine(context: container.mainContext)
        let yoga = try engine.addHabit(name: "Yoga", aliases: ["stretch"])
        let reading = try engine.addHabit(name: "Read")

        #expect(throws: HabitEngineError.habitAlreadyExists("Yoga")) {
            try engine.addHabit(name: "Stretch")
        }
        #expect(throws: HabitEngineError.habitAlreadyExists("Yoga")) {
            try engine.updateHabit(reading, name: "Read", aliases: ["yoga"])
        }

        try engine.updateHabit(yoga, name: "Morning yoga", aliases: ["yoga"])
        #expect(yoga.normalizedName == "morning yoga")
        #expect(yoga.aliases == ["yoga"])
    }

    @Test("Archiving is reversible")
    func archivesAndRestores() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let engine = HabitEngine(context: container.mainContext)
        let habit = try engine.addHabit(name: "Read")

        try engine.setArchived(habit, true)
        #expect(try engine.habits().isEmpty)
        #expect(try engine.habits(includeArchived: true).count == 1)

        try engine.setArchived(habit, false)
        #expect(try engine.habits().count == 1)
    }

    @Test("Dashboard activity excludes voided and archived habit events")
    func filtersDashboardEvents() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let active = Habit(name: "Read")
        let archived = Habit(name: "Run", isArchived: true)
        let visible = HabitEvent(source: .app, habit: active)
        let voided = HabitEvent(source: .app, habit: active)
        voided.voidedAt = .now
        let hidden = HabitEvent(source: .sms, habit: archived)
        context.insert(active)
        context.insert(archived)
        context.insert(visible)
        context.insert(voided)
        context.insert(hidden)
        try context.save()

        let events = try context.fetch(FetchDescriptor<HabitEvent>())
        #expect(HabitVisibility.dashboardEvents(events).map(\.id) == [visible.id])
    }

    @Test("Time-since visibility supports an overall switch and individual habits")
    func controlsTimeSinceVisibility() {
        let visibleHabitID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let hiddenHabitID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let storedValue = TimeSinceVisibility.storedValue(for: [hiddenHabitID])

        #expect(TimeSinceVisibility.hiddenHabitIDs(from: storedValue) == [hiddenHabitID])
        #expect(TimeSinceVisibility.isVisible(
            globally: true,
            hiddenHabitIDs: storedValue,
            for: visibleHabitID
        ))
        #expect(!TimeSinceVisibility.isVisible(
            globally: true,
            hiddenHabitIDs: storedValue,
            for: hiddenHabitID
        ))
        #expect(!TimeSinceVisibility.isVisible(
            globally: false,
            hiddenHabitIDs: "",
            for: visibleHabitID
        ))
    }

    @Test("Sync timestamps always include fractional seconds")
    func syncTimestampPrecision() {
        let date = Date(timeIntervalSince1970: 1_784_752_496.789)
        let encoded = TaliSyncService.encodedTimestamp(date)

        #expect(encoded == "2026-07-22T20:34:56.789Z")
    }

    @Test("Versioned schema opens an existing unversioned Tali store")
    func migratesLegacyStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TaliMigrationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "Tali.store")

        try autoreleasepool {
            let legacySchema = Schema([Habit.self, HabitEvent.self])
            let legacyConfiguration = ModelConfiguration(
                "Tali",
                schema: legacySchema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let legacy = try ModelContainer(for: legacySchema, configurations: [legacyConfiguration])
            let habit = Habit(name: "Read")
            let event = HabitEvent(source: .app, habit: habit)
            legacy.mainContext.insert(habit)
            legacy.mainContext.insert(event)
            try legacy.mainContext.save()
        }

        let migrated = try PersistenceController.makeContainer(storeURL: storeURL)
        #expect(try migrated.mainContext.fetch(FetchDescriptor<Habit>()).count == 1)
        #expect(try migrated.mainContext.fetch(FetchDescriptor<HabitEvent>()).count == 1)
    }

    @Test("Adopting a server habit UUID preserves local events without mutating identity")
    func replacesHabitIdentitySafely() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let local = Habit(name: "Yoga")
        let event = HabitEvent(source: .app, habit: local)
        context.insert(local)
        context.insert(event)
        try context.save()
        let oldID = local.id
        let serverID = UUID()

        let replacement = TaliSyncService.replacingIdentity(
            of: local,
            with: serverID,
            in: context
        )
        try context.save()

        let habits = try context.fetch(FetchDescriptor<Habit>())
        let events = try context.fetch(FetchDescriptor<HabitEvent>())
        #expect(habits.map(\.id) == [serverID])
        #expect(!habits.contains { $0.id == oldID })
        #expect(events.count == 1)
        #expect(events[0].id == event.id)
        #expect(events[0].habit?.id == replacement.id)
    }

    @Test("Exports include archived habits, voided entries, and escaped notes")
    func exportsAllUserData() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let habit = Habit(name: "Read, write", aliases: ["pages"], isArchived: true)
        let event = HabitEvent(
            occurredAt: Date(timeIntervalSince1970: 100),
            createdAt: Date(timeIntervalSince1970: 200),
            source: .sms,
            note: "A \"quoted\" note\nwith a second line",
            habit: habit
        )
        event.voidedAt = Date(timeIntervalSince1970: 300)
        context.insert(habit)
        context.insert(event)
        try context.save()

        let csv = String(decoding: TaliDataExport.csv(habits: [habit], events: [event]), as: UTF8.self)
        #expect(csv.contains("record_type,habit_id"))
        #expect(csv.contains("\"Read, write\""))
        #expect(csv.contains("\"A \"\"quoted\"\" note\nwith a second line\""))
        #expect(csv.contains("voided_at"))

        let json = try TaliDataExport.json(habits: [habit], events: [event])
        let root = try #require(JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect(root["schemaVersion"] as? Int == 1)
        #expect((root["habits"] as? [[String: Any]])?.count == 1)
        #expect((root["entries"] as? [[String: Any]])?.count == 1)
    }
}
