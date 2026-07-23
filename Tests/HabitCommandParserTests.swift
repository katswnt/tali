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

    @Test("Notes follow a double dash")
    func parsesNote() {
        let command = parser.parse("yoga -- hips felt better")
        #expect(command == .log(habit: "yoga", occurredAt: nil, note: "hips felt better"))
    }

    @Test("Query commands are distinguished from logs")
    func parsesQueries() {
        #expect(parser.parse("since yoga") == .since(habit: "yoga"))
        #expect(parser.parse("history meditation") == .history(habit: "meditation"))
        #expect(parser.parse("undo") == .undo)
        #expect(parser.parse("habits") == .list)
    }

    private var parser: HabitCommandParser {
        HabitCommandParser(calendar: calendar, now: { now })
    }
}
