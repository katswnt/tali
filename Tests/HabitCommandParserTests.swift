import Foundation
import Testing
@testable import HabitCore

struct HabitCommandParserTests {
    private let now: Date
    private let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        self.calendar = calendar
        self.now = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 22,
            hour: 18,
            minute: 42
        ))!
    }

    @Test("A bare habit name logs at the default time")
    func parsesBareHabit() {
        let command = parser.parse("yoga")
        #expect(command == .log(habit: "yoga", occurredAt: nil, note: nil))
    }

    @Test("Conversational log prefixes are removed")
    func parsesConversationalLog() {
        let command = parser.parse("I did physical therapy")
        #expect(command == .log(habit: "physical therapy", occurredAt: nil, note: nil))
    }

    @Test("Yesterday and a clock time are resolved in the user calendar")
    func parsesBackdatedLog() {
        let command = parser.parse("meditate yesterday at 7pm")
        let expected = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 21,
            hour: 19
        ))!
        #expect(command == .log(habit: "meditate", occurredAt: expected, note: nil))
    }

    @Test("A weekday and time resolve to the most recent occurrence")
    func parsesWeekdayLog() {
        let expected = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 19,
            hour: 14
        ))!

        #expect(parser.parse("weed sunday 2pm") == .log(habit: "weed", occurredAt: expected, note: nil))
        #expect(parser.parse("weed on Sunday at 2pm") == .log(habit: "weed", occurredAt: expected, note: nil))
    }

    @Test("A weekday time later today resolves to the prior week")
    func avoidsFutureWeekdayLog() {
        let expected = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 15,
            hour: 20
        ))!

        #expect(parser.parse("weed wednesday 8pm") == .log(habit: "weed", occurredAt: expected, note: nil))
    }

    @Test("A clock time can appear before today, yesterday, or a weekday")
    func parsesTimeBeforeDay() throws {
        let lateEvening = try #require(
            iso8601Formatter().date(from: "2026-07-28T05:51:00.000Z")
        )
        let parser = HabitCommandParser(calendar: calendar, now: { lateEvening })
        let today = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 27,
            hour: 21,
            minute: 30
        ))
        let yesterday = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 26,
            hour: 18,
            minute: 30
        ))
        let saturday = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 25,
            hour: 20
        ))

        #expect(parser.parse("alcohol 9:30 pm today") == .log(habit: "alcohol", occurredAt: today, note: nil))
        #expect(parser.parse("alcohol 6:30 pm yesterday") == .log(habit: "alcohol", occurredAt: yesterday, note: nil))
        #expect(parser.parse("alcohol 8pm saturday") == .log(habit: "alcohol", occurredAt: saturday, note: nil))
    }

    @Test("Notes follow a double dash")
    func parsesNote() {
        let command = parser.parse("yoga -- hips felt better")
        #expect(command == .log(habit: "yoga", occurredAt: nil, note: "hips felt better"))
    }

    @Test("Query commands are distinguished from logs")
    func parsesQueries() {
        #expect(parser.parse("since yoga") == .since(habit: "yoga"))
        #expect(parser.parse("time since weed") == .since(habit: "weed"))
        #expect(parser.parse("history meditation") == .history(habit: "meditation"))
        #expect(parser.parse("undo") == .undo)
        #expect(parser.parse("habits") == .list)
        #expect(parser.parse("reshare contact") == .contact)
        #expect(parser.parse("what can you do") == .help)
        #expect(parser.parse("add habit Yoga") == .add(habit: "Yoga", force: false))
        #expect(parser.parse("add habit Uoga anyway") == .add(habit: "Uoga", force: true))
    }

    @Test("Swift parser satisfies the shared app and SMS command contract")
    func satisfiesSharedContract() throws {
        let contract = try JSONDecoder().decode(
            CommandContract.self,
            from: Data(contentsOf: contractURL)
        )
        #expect(contract.version == 4)

        for testCase in contract.cases {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: testCase.timeZone))
            let reference = try #require(iso8601Formatter().date(from: testCase.now))
            let command = HabitCommandParser(calendar: calendar, now: { reference }).parse(testCase.input)
            #expect(canonical(command) == testCase.expected, Comment(rawValue: testCase.name))
        }
    }

    private var parser: HabitCommandParser {
        HabitCommandParser(calendar: calendar, now: { now })
    }

    private var contractURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Fixtures/command-contract-v1.json")
    }

    private func canonical(_ command: HabitCommand) -> ContractCommand {
        switch command {
        case .log(let habit, let occurredAt, let note):
            return ContractCommand(
                type: "log",
                habit: habit,
                occurredAt: occurredAt.map { iso8601Formatter().string(from: $0) },
                note: note
            )
        case .add(let habit, let force):
            return ContractCommand(type: "add", habit: habit, force: force)
        case .since(let habit):
            return ContractCommand(type: "since", habit: habit)
        case .history(let habit):
            return ContractCommand(type: "history", habit: habit)
        case .undo:
            return ContractCommand(type: "undo")
        case .list:
            return ContractCommand(type: "list")
        case .contact:
            return ContractCommand(type: "contact")
        case .help, .unknown:
            return ContractCommand(type: "help")
        }
    }

    private func iso8601Formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

private struct CommandContract: Decodable {
    let version: Int
    let cases: [CommandContractCase]
}

private struct CommandContractCase: Decodable {
    let name: String
    let input: String
    let now: String
    let timeZone: String
    let expected: ContractCommand
}

private struct ContractCommand: Codable, Equatable {
    let type: String
    var habit: String?
    var occurredAt: String?
    var note: String?
    var force: Bool?

    init(
        type: String,
        habit: String? = nil,
        occurredAt: String? = nil,
        note: String? = nil,
        force: Bool? = nil
    ) {
        self.type = type
        self.habit = habit
        self.occurredAt = occurredAt
        self.note = note
        self.force = force
    }
}
