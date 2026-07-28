import Foundation

public enum HabitInputRules {
    public static let maximumNameLength = 80
    public static let maximumAliasLength = 80
    public static let maximumAliasCount = 20
    public static let maximumNoteLength = 1_000

    private static let reservedTerms: Set<String> = [
        "start", "yes", "unstop", "stop", "stopall", "cancel", "end", "quit", "unsubscribe",
        "help", "info", "commands", "command list", "menu", "options", "what can you do",
        "what are the commands", "show commands", "show me the commands", "instructions",
        "how to use tali", "how do i use tali", "how do i use this", "how does this work",
        "how does tali work", "undo", "undo last", "never mind",
        "nevermind", "habits", "list", "list habits", "reshare contact", "share contact",
        "resend contact", "send contact", "history", "stats", "since", "time since", "last",
        "log"
    ]

    public static func validationMessage(
        for term: String,
        label: String = "Habit names and aliases",
        allowedLogTargets: Set<String> = []
    ) -> String? {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = Habit.normalize(trimmed)
        guard !trimmed.isEmpty else { return "Enter a habit name." }
        guard trimmed.count <= maximumNameLength else {
            return "\(label) must be \(maximumNameLength) characters or fewer."
        }
        if reservedTerms.contains(normalized) {
            return "“\(trimmed)” is reserved for a Tali or texting command."
        }
        if matches(trimmed, #"^pair\s+[a-z2-9]{8}$"#) {
            return "“\(trimmed)” is reserved for phone pairing."
        }
        let parsed = HabitCommandParser().parse(trimmed)
        let isPlainLog: Bool
        if case .log(let habit, let occurredAt, let note) = parsed {
            let parsedHabit = Habit.normalize(habit)
            isPlainLog = (parsedHabit == normalized || allowedLogTargets.contains(parsedHabit))
                && occurredAt == nil
                && note == nil
        } else {
            isPlainLog = false
        }
        if !isPlainLog || matches(trimmed, #"\s+again$"#) {
            return "“\(trimmed)” conflicts with Tali’s command or date syntax."
        }
        return nil
    }

    public static func normalizedUniqueAliases(_ aliases: [String]) -> [String] {
        var seen: Set<String> = []
        return aliases.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = Habit.normalize(trimmed)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return trimmed
        }
    }

    public static func looksTemporal(_ value: String) -> Bool {
        matches(
            value,
            #"\s+(today|yesterday|tomorrow|tonight|morning|afternoon|evening|night|sunday|monday|tuesday|wednesday|thursday|friday|saturday|ago)\b"#
        )
            || matches(
                value,
                #"\s+(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+[0-9]{1,2}\b"#
            )
            || matches(value, #"\s+[0-9]{1,2}[/-][0-9]{1,2}(?:[/-][0-9]{2,4})?\b"#)
            || matches(value, #"\s+[0-9]{1,2}(?::[0-9]{2})?\s*(?:a\.?m\.?|p\.?m\.?)\b"#)
            || matches(value, #"\s+[0-9]{1,2}:[0-9]{2}\b"#)
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
