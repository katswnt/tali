import HabitCore
import SwiftData
import SwiftUI

struct LogHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let habits: [Habit]
    @State private var selectedHabitID: UUID?
    @State private var occurredAt = Date.now
    @State private var note = ""
    @State private var errorMessage: String?

    init(habits: [Habit], initialHabit: Habit? = nil) {
        self.habits = habits
        _selectedHabitID = State(initialValue: initialHabit?.id ?? habits.first?.id)
    }

    private var selectedHabit: Habit? {
        habits.first { $0.id == selectedHabitID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Entry") {
                    Picker("Habit", selection: $selectedHabitID) {
                        ForEach(habits) { habit in
                            Text(habit.name).tag(Optional(habit.id))
                        }
                    }
                    DatePicker("When", selection: $occurredAt, in: ...Date.now)
                }

                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }
                }
            }
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { save() }
                        .disabled(selectedHabit == nil)
                }
            }
        }
    }

    private func save() {
        guard let selectedHabit else { return }
        do {
            try HabitEngine(context: modelContext).log(
                habit: selectedHabit,
                at: occurredAt,
                source: .app,
                note: note.isEmpty ? nil : note
            )
            dismiss()
            Task { await SyncCoordinator.syncIfConfigured(context: modelContext) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
