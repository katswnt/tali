import HabitCore
import SwiftData
import SwiftUI

struct HabitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let habit: Habit

    @AppStorage(TimeSinceVisibility.globalPreferenceKey) private var showsTimeSince = true
    @AppStorage(TimeSinceVisibility.hiddenHabitIDsPreferenceKey) private var hiddenTimeSinceHabitIDs = ""

    @State private var showingLog = false
    @State private var showingEdit = false
    @State private var showingArchiveAlert = false
    @State private var eventToUndo: HabitEvent?
    @State private var errorMessage: String?

    private var events: [HabitEvent] {
        habit.events
            .filter { !$0.isVoided }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    var body: some View {
        List {
            Section {
                Button {
                    showingLog = true
                } label: {
                    Label("Add entry", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("habit.addEntry")
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
            }

            if shouldShowTimeSince, let latest = events.first {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TIME SINCE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(HabitFormatting.elapsed(from: latest.occurredAt))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .monospacedDigit()
                        Text(HabitFormatting.timestamp(latest.occurredAt))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                ActivityHeatmapView(
                    habits: [habit],
                    events: events,
                    allowsFiltering: false
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("History") {
                if events.isEmpty {
                    Text("No entries yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(HabitFormatting.timestamp(event.occurredAt))
                            if let note = event.note, !note.isEmpty {
                                Text(note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("habit.event.note")
                            }
                        }
                        .swipeActions {
                            Button("Undo", role: .destructive) {
                                eventToUndo = event
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("habit.detail.list")
        .navigationTitle(habit.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Section("Display") {
                        Toggle(isOn: habitTimeSinceBinding) {
                            Label("Show time since for this habit", systemImage: "timer")
                        }
                        .accessibilityIdentifier("habit.timeSinceToggle")
                        .disabled(!showsTimeSince)
                    }

                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit habit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingArchiveAlert = true
                    } label: {
                        Label("Archive habit", systemImage: "archivebox")
                    }
                } label: {
                    Label("Habit actions", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("habit.actions")
            }
        }
        .sheet(isPresented: $showingLog) {
            LogHabitView(habits: [habit], initialHabit: habit)
        }
        .sheet(isPresented: $showingEdit) {
            EditHabitView(habit: habit)
        }
        .alert("Archive \(habit.name)?", isPresented: $showingArchiveAlert) {
            Button("Archive", role: .destructive) { archive() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its history stays safe, and you can restore it later from Archived Habits.")
        }
        .alert(
            "Undo this entry?",
            isPresented: Binding(
                get: { eventToUndo != nil },
                set: { if !$0 { eventToUndo = nil } }
            ),
        ) {
            Button("Undo entry", role: .destructive) {
                undoSelectedEvent()
            }
            Button("Cancel", role: .cancel) {
                eventToUndo = nil
            }
        } message: {
            Text("It will disappear from your history and activity chart.")
        }
        .alert("Tali couldn’t update this habit", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func archive() {
        do {
            try HabitEngine(context: modelContext).setArchived(habit, true)
            Task { await SyncCoordinator.syncIfConfigured(context: modelContext) }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func undoSelectedEvent() {
        guard let eventToUndo else { return }
        do {
            eventToUndo.voidedAt = .now
            eventToUndo.updatedAt = .now
            try modelContext.save()
            self.eventToUndo = nil
            Task { await SyncCoordinator.syncIfConfigured(context: modelContext) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var shouldShowTimeSince: Bool {
        TimeSinceVisibility.isVisible(
            globally: showsTimeSince,
            hiddenHabitIDs: hiddenTimeSinceHabitIDs,
            for: habit.id
        )
    }

    private var habitTimeSinceBinding: Binding<Bool> {
        Binding(
            get: { shouldShowTimeSince },
            set: { isVisible in
                var hiddenIDs = TimeSinceVisibility.hiddenHabitIDs(from: hiddenTimeSinceHabitIDs)
                if isVisible {
                    hiddenIDs.remove(habit.id)
                } else {
                    hiddenIDs.insert(habit.id)
                }
                hiddenTimeSinceHabitIDs = TimeSinceVisibility.storedValue(for: hiddenIDs)
            }
        )
    }
}

private struct EditHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let habit: Habit
    @State private var name: String
    @State private var aliases: String
    @State private var errorMessage: String?

    init(habit: Habit) {
        self.habit = habit
        _name = State(initialValue: habit.name)
        _aliases = State(initialValue: habit.aliases.joined(separator: ", "))
    }

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
                } header: {
                    Text("Habit")
                } footer: {
                    Text("Name anything you want to observe over time. \(name.count)/\(HabitInputRules.maximumNameLength)")
                }

                Section {
                    TextField("pt, exercises", text: $aliases, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Aliases")
                } footer: {
                    Text("Optional comma-separated phrases you might text to Tali. \(aliasValues.count)/\(HabitInputRules.maximumAliasCount) aliases.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(errorMessage)")
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        do {
            try HabitEngine(context: modelContext).updateHabit(habit, name: name, aliases: aliasValues)
            dismiss()
            Task { await SyncCoordinator.syncIfConfigured(context: modelContext) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
