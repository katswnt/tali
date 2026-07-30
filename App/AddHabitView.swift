import HabitCore
import SwiftData
import SwiftUI

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var aliases = ""
    @State private var errorMessage: String?

    private var aliasValues: [String] {
        aliases
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && name.count <= HabitInputRules.maximumNameLength
            && aliasValues.count <= HabitInputRules.maximumAliasCount
            && aliasValues.allSatisfy { $0.count <= HabitInputRules.maximumAliasLength }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Habit name", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("habit.add.name")
                } header: {
                    Text("Habit")
                } footer: {
                    Text("Name anything you want to observe over time. \(name.count)/\(HabitInputRules.maximumNameLength)")
                }

                Section {
                    TextField("pt, exercises", text: $aliases, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("habit.add.aliases")
                } header: {
                    Text("Aliases")
                } footer: {
                    Text("Optional comma-separated phrases you might type in Messages. \(aliasValues.count)/\(HabitInputRules.maximumAliasCount) aliases.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(errorMessage)")
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("habit.add.confirm")
                }
            }
        }
    }

    private func save() {
        do {
            try HabitEngine(context: modelContext).addHabit(name: name, aliases: aliasValues)
            dismiss()
            Task { await SyncCoordinator.syncIfConfigured(context: modelContext) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
