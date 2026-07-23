import HabitCore
import SwiftUI

struct ActivityHeatmapView: View {
    let habits: [Habit]
    let events: [HabitEvent]
    let allowsFiltering: Bool

    @State private var selectedHabitID: UUID?
    @State private var selectedDate: Date?
    private let calendar = Calendar.autoupdatingCurrent
    private let weekCount = 17
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

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

    private var selectedDay: HeatmapDay? {
        guard let selectedDate else { return nil }
        return weeks
            .joined()
            .first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
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

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        Text(weekdayLabel(for: dayIndex))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: cellSize)
                    }
                }
                .padding(.top, 21)
                .accessibilityHidden(true)

                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: cellSpacing) {
                            ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                                ZStack(alignment: .leading) {
                                    if let label = monthLabel(for: week, at: index) {
                                        Text(label)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .fixedSize()
                                    }
                                }
                                .frame(width: cellSize, height: 15, alignment: .leading)
                            }
                        }
                        .accessibilityHidden(true)

                        HStack(alignment: .top, spacing: cellSpacing) {
                            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                                VStack(spacing: cellSpacing) {
                                    ForEach(week) { day in
                                        Button {
                                            selectedDate = day.date
                                        } label: {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(color(for: day.count))
                                                .frame(width: cellSize, height: cellSize)
                                                .overlay {
                                                    if let selectedDate,
                                                       calendar.isDate(day.date, inSameDayAs: selectedDate) {
                                                        RoundedRectangle(cornerRadius: 3)
                                                            .stroke(.primary.opacity(0.7), lineWidth: 1.5)
                                                    }
                                                }
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(day.count < 0)
                                        .accessibilityLabel(accessibilityLabel(for: day))
                                        .accessibilityHint("Shows the entry count for this date")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }

            activityCaption

            HStack(spacing: 6) {
                Text("No entry")
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: 0))
                    .frame(width: 11, height: 11)
                    .accessibilityHidden(true)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: 1))
                    .frame(width: 11, height: 11)
                    .accessibilityHidden(true)
                Text("Recorded")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .onChange(of: selectedHabitID) {
            selectedDate = nil
        }
    }

    @ViewBuilder
    private var activityCaption: some View {
        if let selectedDay {
            HStack {
                Text(selectedDay.date.formatted(.dateTime.month(.abbreviated).day().year()))
                Spacer()
                Text(entryCountLabel(selectedDay.count))
                    .monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        } else {
            Text(visibleEvents.isEmpty ? "Activity will appear here." : "Tap a day to see its entries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func monthLabel(for week: [HeatmapDay], at index: Int) -> String? {
        if index == 0 {
            let labelDate = week.first(where: {
                calendar.component(.day, from: $0.date) == 1
            })?.date ?? week.first?.date
            return labelDate?.formatted(.dateTime.month(.abbreviated))
        }

        guard let firstOfMonth = week.first(where: {
            calendar.component(.day, from: $0.date) == 1
        }) else {
            return nil
        }
        return firstOfMonth.date.formatted(.dateTime.month(.abbreviated))
    }

    private func weekdayLabel(for index: Int) -> String {
        guard index == 1 || index == 3 || index == 5 else { return "" }
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    private func entryCountLabel(_ count: Int) -> String {
        count == 1 ? "1 entry" : "\(count) entries"
    }

    private func color(for count: Int) -> Color {
        switch count {
        case ..<0:
            return Color.clear
        case 0:
            return Color(.tertiarySystemFill)
        default:
            return .blue
        }
    }

    private func accessibilityLabel(for day: HeatmapDay) -> String {
        guard day.count >= 0 else { return "Future date" }
        let date = day.date.formatted(date: .complete, time: .omitted)
        return "\(date), \(entryCountLabel(day.count))"
    }
}

private struct HeatmapDay: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}
