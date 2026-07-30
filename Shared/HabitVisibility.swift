import Foundation

public enum HabitVisibility {
    public static func dashboardEvents(_ events: [HabitEvent]) -> [HabitEvent] {
        events.filter { event in
            !event.isVoided && event.habit?.isArchived == false
        }
        .sorted {
            if $0.occurredAt != $1.occurredAt {
                return $0.occurredAt > $1.occurredAt
            }
            return $0.createdAt > $1.createdAt
        }
    }
}

public enum TimeSinceVisibility {
    public static let globalPreferenceKey = "tali.display.showTimeSince"
    public static let hiddenHabitIDsPreferenceKey = "tali.display.hiddenTimeSinceHabitIDs"

    public static func hiddenHabitIDs(from storedValue: String) -> Set<UUID> {
        Set(
            storedValue
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
        )
    }

    public static func storedValue(for hiddenHabitIDs: Set<UUID>) -> String {
        hiddenHabitIDs
            .map(\.uuidString)
            .sorted()
            .joined(separator: ",")
    }

    public static func isVisible(
        globally: Bool,
        hiddenHabitIDs storedValue: String,
        for habitID: UUID
    ) -> Bool {
        globally && !hiddenHabitIDs(from: storedValue).contains(habitID)
    }
}
