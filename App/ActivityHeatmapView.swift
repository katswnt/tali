import HabitCore
import SwiftUI

struct ActivityHeatmapView: View {
    let habits: [Habit]
    let events: [HabitEvent]
    let allowsFiltering: Bool

    @State private var selectedHabitID: UUID?
    private let calendar = Calendar.autoupdatingCurrent
    private let weekCount = 17

    init(habits: [Habit], events: [HabitEvent], allowsFiltering: Bool = true) {
        self.habits = habits
        self.events = events
        self.allowsFiltering = allowsFiltering
    }

    private var selectedHabitName: String {
        habits.first(where: { $0.id == selectedHabitID })?.name ?? "All habits"
    }

    private var visibleEvents: [HabitEvent] {
        guard let selectedHabitID else { return events }
        return events.filter { $0.habit?.id == selectedHabitID }
    }

    private var weeks: [[HeatmapDay]] {
        let today = calendar.startOfDay(for: .now)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let firstWeekStart = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: currentWeekStart) ?? currentWeekStart

        let counts = Dictionary(grouping: visibleEvents) { event in
            calendar.startOfDay(for: event.occurredAt)
        }.mapValues(\.count)

        return (0..<weekCount).map { weekOffset in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: firstWeekStart) ?? firstWeekStart
            return (0..<7).map { dayOffset in
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
                return HeatmapDay(date: date, count: date <= today ? counts[date, default: 0] : -1)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity")
                        .font(.title3.weight(.semibold))
                    Text("Past four months")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if allowsFiltering {
                    Menu {
                        Button("All habits") { selectedHabitID = nil }
                        ForEach(habits) { habit in
                            Button(habit.name) { selectedHabitID = habit.id }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(selectedHabitName)
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .accessibilityLabel("Activity filter, \(selectedHabitName)")
                }
            }

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 4) {
                            ForEach(week) { day in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color(for: day.count))
                                    .frame(width: 15, height: 15)
                                    .accessibilityLabel(accessibilityLabel(for: day))
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 5) {
                Text("0")
                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: level))
                        .frame(width: 11, height: 11)
                        .accessibilityHidden(true)
                }
                Text("4+")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func color(for count: Int) -> Color {
        switch count {
        case ..<0: return Color.clear
        case 0: return Color(.tertiarySystemFill)
        case 1: return .blue.opacity(0.25)
        case 2: return .blue.opacity(0.45)
        case 3: return .blue.opacity(0.65)
        default: return .blue.opacity(0.85)
        }
    }

    private func accessibilityLabel(for day: HeatmapDay) -> String {
        guard day.count >= 0 else { return "Future date" }
        let date = day.date.formatted(date: .complete, time: .omitted)
        let activity = day.count == 1 ? "1 entry" : "\(day.count) entries"
        return "\(date), \(activity)"
    }
}

private struct HeatmapDay: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}
