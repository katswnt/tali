import Foundation

public enum HabitCommand: Equatable {
    case log(habit: String, occurredAt: Date?, note: String?)
    case since(habit: String)
    case history(habit: String)
    case undo
    case list
    case help
    case unknown(String)
}

public struct HabitCommandParser {
    public var calendar: Calendar
    public var now: () -> Date

    public init(calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.calendar = calendar
        self.now = now
    }

    public func parse(_ input: String) -> HabitCommand {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .help }

        let normalized = Habit.normalize(trimmed)
        switch normalized {
        case "undo", "undo last", "never mind", "nevermind":
            return .undo
        case "habits", "list", "list habits":
            return .list
        case "help", "?":
            return .help
        default:
            break
        }

        if let value = value(afterAnyPrefix: ["since ", "when did i ", "when was ", "last "], in: normalized) {
            return value.isEmpty ? .help : .since(habit: value)
        }

        if let value = value(afterAnyPrefix: ["history ", "stats "], in: normalized) {
            return value.isEmpty ? .help : .history(habit: value)
        }

        let logText = removingLogPrefix(from: trimmed)

        let noteParts = logText.components(separatedBy: " -- ")
        let note = noteParts.count > 1
            ? noteParts.dropFirst().joined(separator: " -- ").trimmingCharacters(in: .whitespaces)
            : nil
        let valueWithDate = noteParts[0]
        let dated = extractDate(from: valueWithDate)

        guard !dated.habit.isEmpty else { return .unknown(trimmed) }
        return .log(habit: dated.habit, occurredAt: dated.date, note: note)
    }

    private func removingLogPrefix(from value: String) -> String {
        let pattern = #"^(?:#did|i\s+did|did|log)\s+"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = expression.firstMatch(in: value, range: range),
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

    private func extractDate(from input: String) -> (habit: String, date: Date?) {
        let weekdays = "sunday|monday|tuesday|wednesday|thursday|friday|saturday"
        let pattern = #"\s+(?:on\s+)?(?:(last)\s+)?(today|yesterday|"#
            + weekdays
            + #")(?:\s+(?:at\s+)?([0-9]{1,2}(?::[0-9]{2})?\s*(?:am|pm)?))?$"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return (input, nil)
        }

        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        guard let match = expression.firstMatch(in: input, range: range),
              let fullRange = Range(match.range(at: 0), in: input),
              let dayRange = Range(match.range(at: 2), in: input) else {
            return (input.trimmingCharacters(in: .whitespaces), nil)
        }

        let habit = String(input[..<fullRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let dayWord = String(input[dayRange]).lowercased()
        let reference = now()
        let explicitlyLast = match.range(at: 1).location != NSNotFound
        let base = resolvedDay(dayWord, explicitlyLast: explicitlyLast, reference: reference)

        guard match.range(at: 3).location != NSNotFound,
              let timeRange = Range(match.range(at: 3), in: input),
              let time = parsedTime(String(input[timeRange])) else {
            return (habit, calendar.startOfDay(for: base))
        }

        let components = calendar.dateComponents([.hour, .minute], from: time)
        guard var resolved = calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: base
        ) else {
            return (habit, calendar.startOfDay(for: base))
        }
        if weekdayNumber(for: dayWord) != nil,
           !explicitlyLast,
           resolved > reference {
            resolved = calendar.date(byAdding: .day, value: -7, to: resolved) ?? resolved
        }
        return (habit, resolved)
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

    private func parsedTime(_ input: String) -> Date? {
        let compact = input.replacingOccurrences(of: " ", with: "").lowercased()
        let formats = compact.contains("m")
            ? ["h:mma", "ha"]
            : ["H:mm", "H"]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: compact) {
                return date
            }
        }
        return nil
    }
}
