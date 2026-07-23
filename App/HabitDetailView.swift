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
                if let latest = events.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(shouldShowTimeSince ? "TIME SINCE" : "LAST ENTRY")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if shouldShowTimeSince {
                            Text(HabitFormatting.elapsed(from: latest.occurredAt))
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .monospacedDigit()
                        }
                        Text(HabitFormatting.timestamp(latest.occurredAt))
                            .font(shouldShowTimeSince ? .subheadline : .title3.weight(.medium))
                            .foregroundStyle(shouldShowTimeSince ? .secondary : .primary)
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                } else {
                    ContentUnavailableView(
                        "Never logged",
                        systemImage: "calendar.badge.plus",
                        description: Text("Entries for this habit will appear here.")
                    )
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
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(HabitFormatting.timestamp(event.occurredAt))
                        if let note = event.note, !note.isEmpty {
                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
        .navigationTitle(habit.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Section("Display") {
                        Toggle(isOn: habitTimeSinceBinding) {
                            Label("Show time since for this habit", systemImage: "timer")
                        }
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

                Button {
                    showingLog = true
                } label: {
                    Label("Add an entry for \(habit.name)", systemImage: "plus.circle.fill")
                }
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

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                    Text("Name anything you want to observe over time.")
                }

                Section {
                    TextField("pt, exercises", text: $aliases, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Aliases")
                } footer: {
                    Text("Optional comma-separated phrases you might text to Tali.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(errorMessage)")
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
            let values = aliases
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            try HabitEngine(context: modelContext).updateHabit(habit, name: name, aliases: values)
            dismiss()
            Task { await SyncCoordinator.syncIfConfigured(context: modelContext) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
