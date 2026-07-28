import Foundation

public enum HabitCommand: Equatable {
    case log(habit: String, occurredAt: Date?, note: String?)
    case add(habit: String, force: Bool)
    case since(habit: String)
    case history(habit: String)
    case undo
    case list
    case contact
    case help
    case invalid(String)
}

public struct HabitCommandParser {
    public var calendar: Calendar
    public var now: () -> Date

    private static let dayWords =
        "today|yesterday|sunday|monday|tuesday|wednesday|thursday|friday|saturday"
    private static let clockPattern =
        #"[0-9]{1,2}(?::[0-9]{2})?\s*(?:a\.?m\.?|p\.?m\.?)?"#
    private static let ambiguousTimeMessage =
        "Include AM or PM for times from 1–12. Example: yoga yesterday 7pm."
    private static let invalidTimeMessage =
        "I couldn't understand that time. Try a time like 7pm or 19:00."
    private static let unsupportedDateMessage =
        "I couldn't understand that date or time, so nothing was logged. Try: yoga yesterday 7pm."

    public init(calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.calendar = calendar
        self.now = now
    }

    public func parse(_ input: String) -> HabitCommand {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .help }

        let normalized = Habit.normalize(trimmed)
        let commandValue = normalized
            .replacingOccurrences(of: #"[.!?]+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard !commandValue.isEmpty else { return .help }
        switch commandValue {
        case "undo", "undo last", "never mind", "nevermind":
            return .undo
        case "habits", "list", "list habits":
            return .list
        case "help", "info", "commands", "command list", "menu", "options", "what can you do",
             "what are the commands", "show commands", "show me the commands", "instructions",
             "how to use tali", "how do i use tali", "how do i use this", "how does this work",
             "how does tali work":
            return .help
        case "reshare contact", "share contact", "resend contact", "send contact":
            return .contact
        case "history", "stats", "since", "time since", "last", "log":
            return .help
        default:
            break
        }

        if let match = trimmed.firstMatch(
            pattern: #"^(?:add|create|new)\s+habit(?:\s+(.*))?$"#,
            options: .caseInsensitive
        ) {
            let requested = match.capture(1, in: trimmed)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !requested.isEmpty else { return .help }
            if let forceMatch = requested.firstMatch(
                pattern: #"^(.*?)\s+anyway$"#,
                options: .caseInsensitive
            ) {
                let habit = forceMatch.capture(1, in: requested)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return habit.isEmpty ? .help : .add(habit: habit, force: true)
            }
            return .add(habit: requested, force: false)
        }

        if let value = value(
            afterAnyPrefix: ["time since ", "how long since ", "since ", "when did i ", "when was ", "last "],
            in: commandValue
        ) {
            return value.isEmpty ? .help : .since(habit: value)
        }

        if let value = value(afterAnyPrefix: ["history ", "stats "], in: commandValue) {
            return value.isEmpty ? .help : .history(habit: value)
        }

        let logText = removingLogPrefix(from: trimmed)
        let standardized = logText.replacingOccurrences(
            of: #"\s+--\s+"#,
            with: "\u{001F}",
            options: .regularExpression
        )
        let noteParts = standardized.components(separatedBy: "\u{001F}")
        let note = noteParts.count > 1
            ? noteParts.dropFirst().joined(separator: " -- ").trimmingCharacters(in: .whitespaces)
            : nil
        if let note, note.count > HabitInputRules.maximumNoteLength {
            return .invalid("Notes must be \(HabitInputRules.maximumNoteLength) characters or fewer.")
        }

        let dated = extractDate(from: noteParts[0])
        if let error = dated.error { return .invalid(error) }
        guard !dated.habit.isEmpty else { return .help }
        guard dated.habit.count <= HabitInputRules.maximumNameLength else {
            return .invalid("Habit names must be \(HabitInputRules.maximumNameLength) characters or fewer.")
        }
        return .log(habit: dated.habit, occurredAt: dated.date, note: note)
    }

    private func removingLogPrefix(from value: String) -> String {
        let pattern = #"^(?:#did|i\s+did|did|log)\s+"#
        guard let match = value.firstMatch(pattern: pattern, options: .caseInsensitive),
              let matchRange = Range(match.range, in: value) else {
            return value
        }
        return String(value[matchRange.upperBound...])
    }

    private func value(afterAnyPrefix prefixes: [String], in value: String) -> String? {
        for prefix in prefixes where value.hasPrefix(prefix) {
            return String(value.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private func extractDate(from input: String) -> DateExtraction {
        let timeFirstPattern = #"\s+(?:at\s+)?("#
            + Self.clockPattern
            + #")\s+(?:on\s+)?(?:(last)\s+)?("#
            + Self.dayWords
            + #")[.!]?$"#
        let dayFirstPattern = #"\s+(?:on\s+)?(?:(last)\s+)?("#
            + Self.dayWords
            + #")(?:\s+(?:at\s+)?("#
            + Self.clockPattern
            + #"))?[.!]?$"#

        let match: NSTextCheckingResult?
        let lastCapture: Int
        let dayCapture: Int
        let timeCapture: Int
        if let timeFirst = input.firstMatch(pattern: timeFirstPattern, options: .caseInsensitive) {
            match = timeFirst
            timeCapture = 1
            lastCapture = 2
            dayCapture = 3
        } else if let dayFirst = input.firstMatch(pattern: dayFirstPattern, options: .caseInsensitive) {
            match = dayFirst
            lastCapture = 1
            dayCapture = 2
            timeCapture = 3
        } else {
            match = nil
            lastCapture = 0
            dayCapture = 0
            timeCapture = 0
        }

        if let match,
           let fullRange = Range(match.range(at: 0), in: input),
           let dayRange = Range(match.range(at: dayCapture), in: input) {
            let habit = String(input[..<fullRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let dayWord = String(input[dayRange]).lowercased()
            guard !habit.isEmpty else {
                return DateExtraction(habit: "", error: "Include a habit before the date and time.")
            }
            guard match.range(at: timeCapture).location != NSNotFound,
                  let timeRange = Range(match.range(at: timeCapture), in: input) else {
                return DateExtraction(
                    habit: habit,
                    error: "What time \(dayWord)? Example: \(habit) \(dayWord) 7pm."
                )
            }
            let parsed = parsedTime(String(input[timeRange]))
            if let error = parsed.error { return DateExtraction(habit: habit, error: error) }

            let reference = now()
            let explicitlyLast = match.range(at: lastCapture).location != NSNotFound
            var base = resolvedDay(dayWord, explicitlyLast: explicitlyLast, reference: reference)
            guard var resolved = strictDate(
                on: base,
                hour: parsed.hour,
                minute: parsed.minute
            ) else {
                return DateExtraction(
                    habit: habit,
                    error: "That local time doesn't exist because of a daylight-saving change."
                )
            }
            if weekdayNumber(for: dayWord) != nil, !explicitlyLast, resolved > reference {
                base = calendar.date(byAdding: .day, value: -7, to: base) ?? base
                guard let prior = strictDate(on: base, hour: parsed.hour, minute: parsed.minute) else {
                    return DateExtraction(
                        habit: habit,
                        error: "That local time doesn't exist because of a daylight-saving change."
                    )
                }
                resolved = prior
            }
            if resolved.timeIntervalSince(reference) > 60 {
                return DateExtraction(habit: habit, error: "That time is in the future, so nothing was logged.")
            }
            return DateExtraction(habit: habit, date: resolved)
        }

        if let ago = input.firstMatch(
            pattern: #"\s+([0-9]+)\s+(minute|hour|day)s?\s+ago[.!]?$"#,
            options: .caseInsensitive
        ), let fullRange = Range(ago.range(at: 0), in: input) {
            let habit = String(input[..<fullRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let amount = Int(ago.capture(1, in: input) ?? "") ?? 0
            let unit = (ago.capture(2, in: input) ?? "").lowercased()
            let component: Calendar.Component = unit == "day" ? .day : unit == "hour" ? .hour : .minute
            let maximum = unit == "day" ? 3_650 : unit == "hour" ? 87_600 : 5_256_000
            guard !habit.isEmpty, amount >= 1, amount <= maximum,
                  let date = calendar.date(byAdding: component, value: -amount, to: now()) else {
                return DateExtraction(habit: habit, error: Self.unsupportedDateMessage)
            }
            return DateExtraction(habit: habit, date: date)
        }

        let timeOnlyPattern = #"\s+(?:at\s+)?("# + Self.clockPattern + #")[.!]?$"#
        if let timeOnly = input.firstMatch(pattern: timeOnlyPattern, options: .caseInsensitive),
           let fullRange = Range(timeOnly.range(at: 0), in: input),
           let clock = timeOnly.capture(1, in: input) {
            let habit = String(input[..<fullRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard !habit.isEmpty else {
                return DateExtraction(habit: "", error: "Include a habit before the time.")
            }
            if HabitInputRules.looksTemporal(habit) {
                return DateExtraction(habit: habit, error: Self.unsupportedDateMessage)
            }
            let parsed = parsedTime(clock)
            if let error = parsed.error { return DateExtraction(habit: habit, error: error) }
            let reference = now()
            guard let resolved = strictDate(on: reference, hour: parsed.hour, minute: parsed.minute) else {
                return DateExtraction(
                    habit: habit,
                    error: "That local time doesn't exist because of a daylight-saving change."
                )
            }
            if resolved.timeIntervalSince(reference) > 60 {
                return DateExtraction(
                    habit: habit,
                    error: "That time is still in the future today. Include a day, such as “\(habit) yesterday \(clock)”."
                )
            }
            return DateExtraction(habit: habit, date: resolved)
        }

        if HabitInputRules.looksTemporal(input) {
            return DateExtraction(habit: input, error: Self.unsupportedDateMessage)
        }
        return DateExtraction(habit: input.trimmingCharacters(in: .whitespaces))
    }

    private func resolvedDay(_ word: String, explicitlyLast: Bool, reference: Date) -> Date {
        if word == "today" { return reference }
        if word == "yesterday" {
            return calendar.date(byAdding: .day, value: -1, to: reference) ?? reference
        }
        guard let targetWeekday = weekdayNumber(for: word) else { return reference }
        let currentWeekday = calendar.component(.weekday, from: reference)
        var daysBack = (currentWeekday - targetWeekday + 7) % 7
        if explicitlyLast && daysBack == 0 { daysBack = 7 }
        return calendar.date(byAdding: .day, value: -daysBack, to: reference) ?? reference
    }

    private func weekdayNumber(for word: String) -> Int? {
        [
            "sunday": 1,
            "monday": 2,
            "tuesday": 3,
            "wednesday": 4,
            "thursday": 5,
            "friday": 6,
            "saturday": 7,
        ][word]
    }

    private func parsedTime(_ input: String) -> ParsedTime {
        let compact = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .lowercased()
        guard let match = compact.firstMatch(pattern: #"^([0-9]{1,2})(?::([0-9]{2}))?(am|pm)?$"#),
              let hourText = match.capture(1, in: compact),
              var hour = Int(hourText) else {
            return ParsedTime(error: Self.invalidTimeMessage)
        }
        let minute = Int(match.capture(2, in: compact) ?? "0") ?? -1
        let meridiem = match.capture(3, in: compact)
        guard minute >= 0, minute <= 59 else {
            return ParsedTime(error: Self.invalidTimeMessage)
        }
        if let meridiem {
            guard hour >= 1, hour <= 12 else {
                return ParsedTime(error: Self.invalidTimeMessage)
            }
            if meridiem == "pm", hour < 12 { hour += 12 }
            if meridiem == "am", hour == 12 { hour = 0 }
            return ParsedTime(hour: hour, minute: minute)
        }
        if hour >= 1, hour <= 12 {
            return ParsedTime(error: Self.ambiguousTimeMessage)
        }
        guard hour >= 0, hour <= 23 else {
            return ParsedTime(error: Self.invalidTimeMessage)
        }
        return ParsedTime(hour: hour, minute: minute)
    }

    private func strictDate(on date: Date, hour: Int, minute: Int) -> Date? {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        var components = DateComponents()
        components.timeZone = calendar.timeZone
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let resolved = calendar.date(from: components) else { return nil }
        let roundTrip = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: resolved)
        guard roundTrip.year == components.year,
              roundTrip.month == components.month,
              roundTrip.day == components.day,
              roundTrip.hour == hour,
              roundTrip.minute == minute else {
            return nil
        }
        return resolved
    }
}

private struct DateExtraction {
    let habit: String
    var date: Date?
    var error: String?

    init(habit: String, date: Date? = nil, error: String? = nil) {
        self.habit = habit
        self.date = date
        self.error = error
    }
}

private struct ParsedTime {
    var hour = 0
    var minute = 0
    var error: String?

    init(hour: Int = 0, minute: Int = 0, error: String? = nil) {
        self.hour = hour
        self.minute = minute
        self.error = error
    }
}

private extension String {
    func firstMatch(
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSTextCheckingResult? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        return expression.firstMatch(in: self, range: range)
    }
}

private extension NSTextCheckingResult {
    func capture(_ index: Int, in value: String) -> String? {
        guard range(at: index).location != NSNotFound,
              let range = Range(range(at: index), in: value) else {
            return nil
        }
        return String(value[range])
    }
}
