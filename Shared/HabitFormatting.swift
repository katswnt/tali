import Foundation

public enum HabitFormatting {
    public static func elapsed(from start: Date, to end: Date = .now) -> String {
        let interval = max(0, end.timeIntervalSince(start))
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 86_400 ? [.day, .hour] : [.hour, .minute]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: interval) ?? "just now"
    }

    public static func timestamp(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    public static func relative(_ date: Date, now: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
