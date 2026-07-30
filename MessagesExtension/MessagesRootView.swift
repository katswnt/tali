import HabitCore
import SwiftData
import SwiftUI

struct HabitReceipt: Equatable {
    let habitName: String
    let occurredAt: Date
}

struct MessagesRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.name) private var habits: [Habit]

    let onInsertReceipt: (HabitReceipt) -> Void

    @State private var command = ""
    @State private var feedback: String?
    @State private var errorMessage: String?
    @State private var receipt: HabitReceipt?
    @FocusState private var commandIsFocused: Bool
    private let smsGreen = Color(red: 0.204, green: 0.780, blue: 0.349)

    private var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !PersistenceController.isSharedContainerAvailable {
                    Label(
                        "This simulator is using local extension storage.",
                        systemImage: "externaldrive.badge.exclamationmark"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                commandField
                recentHabits
                result
                helpText
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .tint(smsGreen)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.bullet")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(smsGreen, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Tali")
                    .font(.headline)
                Text("Log without leaving Messages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var commandField: some View {
        HStack(spacing: 10) {
            TextField("yoga yesterday at 7pm", text: $command)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .focused($commandIsFocused)
                .onSubmit(submit)

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(commandIsEmpty ? Color.secondary : smsGreen, in: Circle())
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .disabled(commandIsEmpty)
            .accessibilityLabel("Submit habit command")
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var recentHabits: some View {
        if !activeHabits.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("HABITS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(activeHabits.prefix(6)) { habit in
                            Button(habit.name) {
                                command = habit.name
                                submit()
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    @ViewBuilder
    private var result: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.circle")
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Error: \(errorMessage)")
                .accessibilityAddTraits(.updatesFrequently)
        } else if let feedback {
            VStack(alignment: .leading, spacing: 10) {
                Label(feedback, systemImage: "info.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if let receipt {
                    Button {
                        onInsertReceipt(receipt)
                    } label: {
                        Label("Add text receipt to conversation", systemImage: "message")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private var helpText: some View {
        Text("Try “add habit yoga,” “time since yoga,” “habits,” or “undo.” Add a note after --")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var commandIsEmpty: Bool {
        command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard !commandIsEmpty else { return }
        do {
            let engine = HabitEngine(context: modelContext)
            let againMatch = command.range(
                of: #"\s+again\s*$"#,
                options: [.regularExpression, .caseInsensitive]
            )
            let allowsDuplicate = againMatch != nil
            let commandText = againMatch.map { String(command[..<$0.lowerBound]) } ?? command
            let parsed = HabitCommandParser().parse(commandText)
            if allowsDuplicate, case .log = parsed {
                // The explicit override intentionally bypasses the duplicate checks below.
            } else if allowsDuplicate {
                throw HabitEngineError.invalidHabitTerm(
                    "“again” can only follow a habit log, such as “yoga again”."
                )
            } else if case .log(let query, let date, _) = parsed {
                let habit = try engine.resolveHabit(query)
                let active = engine.activeEvents(for: habit)
                if let date, active.contains(where: { $0.occurredAt == date }) {
                    throw HabitEngineError.invalidHabitTerm(
                        "\(habit.name) is already logged for \(HabitFormatting.timestamp(date)). "
                            + "Enter “\(commandText) again” to log another."
                    )
                }
                if date == nil,
                   let recent = active.max(by: { $0.createdAt < $1.createdAt }),
                   Date.now.timeIntervalSince(recent.createdAt) < 5 * 60,
                   abs(Date.now.timeIntervalSince(recent.occurredAt)) < 5 * 60 {
                    throw HabitEngineError.invalidHabitTerm(
                        "\(habit.name) was already logged recently. Enter “\(habit.name) again” to log another."
                    )
                }
            }
            let response = try engine.execute(parsed, source: .messages)
            feedback = message(for: response)
            errorMessage = nil

            if case .logged(let result) = response {
                receipt = HabitReceipt(habitName: result.habit.name, occurredAt: result.event.occurredAt)
            } else {
                receipt = nil
            }
            command = ""
            commandIsFocused = false
        } catch {
            feedback = nil
            receipt = nil
            errorMessage = error.localizedDescription
        }
    }

    private func message(for response: HabitResponse) -> String {
        switch response {
        case .logged(let result):
            let timestamp = HabitFormatting.timestamp(result.event.occurredAt)
            if let previous = result.previousEvent {
                let gap = HabitFormatting.elapsed(from: previous.occurredAt, to: result.event.occurredAt)
                return "Logged \(result.habit.name) for \(timestamp). Previous: \(gap)."
            }
            return "Logged \(result.habit.name) for \(timestamp). No earlier entries."
        case .added(let habit):
            return "Added \(habit.name). Text “\(habit.name)” anytime to log it."
        case .since(let habit, let event):
            guard let event else { return "\(habit.name) has never been logged." }
            return "\(habit.name): \(HabitFormatting.elapsed(from: event.occurredAt))."
        case .history(let habit, let events):
            guard let latest = events.first else { return "\(habit.name) has no history yet." }
            return "\(habit.name): \(events.count) recent logs. Latest \(HabitFormatting.relative(latest.occurredAt))."
        case .undone(let event):
            return "Undid \(event.habit?.name ?? "the latest entry") from \(HabitFormatting.timestamp(event.occurredAt))."
        case .habits(let habits):
            return habits.map(\.name).joined(separator: ", ")
        }
    }
}
