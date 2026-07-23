import HabitCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.name) private var habits: [Habit]
    @Query(sort: \HabitEvent.occurredAt, order: .reverse) private var events: [HabitEvent]

    @AppStorage(TimeSinceVisibility.globalPreferenceKey) private var showsTimeSince = true
    @AppStorage(TimeSinceVisibility.hiddenHabitIDsPreferenceKey) private var hiddenTimeSinceHabitIDs = ""

    @State private var showingAddHabit = false
    @State private var showingLog = false
    @State private var showingSyncSettings = false
    @State private var showingArchivedHabits = false
    @State private var syncError: String?
    @State private var syncStatus = SyncCoordinator.status
    @State private var exportDocument: TaliExportDocument?
    @State private var exportType: UTType = .commaSeparatedText
    @State private var exportFilename = "Tali export"
    @State private var showingExporter = false
    @State private var isPreparingExport = false
    @State private var exportError: String?

    private var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }

    private var activeEvents: [HabitEvent] {
        HabitVisibility.dashboardEvents(events)
    }

    private var archivedHabits: [Habit] {
        habits.filter(\.isArchived)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    syncStatusSection
                    if activeHabits.isEmpty {
                        emptyDashboardSection

                        ActivityHeatmapView(
                            habits: [],
                            events: []
                        )
                    } else {
                        mostRecentSection

                        ActivityHeatmapView(
                            habits: activeHabits,
                            events: activeEvents
                        )

                        habitsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tali")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section {
                            Button {
                                showingAddHabit = true
                            } label: {
                                Label("Add habit", systemImage: "plus")
                            }

                            Button {
                                showingSyncSettings = true
                            } label: {
                                Label("Texting", systemImage: "message")
                            }
                        }

                        Section("Display") {
                            Toggle(isOn: $showsTimeSince) {
                                Label("Show time since", systemImage: "timer")
                            }
                        }

                        if !archivedHabits.isEmpty {
                            Button {
                                showingArchivedHabits = true
                            } label: {
                                Label("Archived habits", systemImage: "archivebox")
                            }
                        }

                        Section("Export") {
                            Button {
                                exportCSV()
                            } label: {
                                Label("All data as CSV", systemImage: "tablecells")
                            }

                            Button {
                                exportJSON()
                            } label: {
                                Label(
                                    isPreparingExport ? "Preparing archive…" : "Complete archive as JSON",
                                    systemImage: "doc.text"
                                )
                            }
                            .disabled(isPreparingExport)
                        }
                    } label: {
                        Label("More options", systemImage: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLog = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Log")
                        }
                        .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Log an entry")
                    .disabled(activeHabits.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView()
            }
            .sheet(isPresented: $showingLog) {
                LogHabitView(habits: activeHabits)
            }
            .sheet(isPresented: $showingSyncSettings) {
                SyncSettingsView()
            }
            .sheet(isPresented: $showingArchivedHabits) {
                ArchivedHabitsView()
            }
            .refreshable {
                await sync()
            }
            .alert("Tali couldn’t sync", isPresented: Binding(
                get: { syncError != nil },
                set: { if !$0 { syncError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncError ?? "Unknown error")
            }
            .alert("Tali couldn’t export data", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "Unknown error")
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: exportType,
                defaultFilename: exportFilename
            ) { result in
                if case .failure(let error) = result {
                    exportError = error.localizedDescription
                }
                exportDocument = nil
            }
        }
        .tint(.blue)
    }

    private var emptyDashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Track something", systemImage: "list.bullet.clipboard")
                .font(.title2.weight(.semibold))

            Text("Add a habit, then log it whenever it happens.")
                .font(.body)
                .foregroundStyle(.secondary)

            Button("Add a habit") {
                showingAddHabit = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var syncStatusSection: some View {
        if syncStatus.isSyncing {
            HStack(spacing: 10) {
                ProgressView()
                Text("Syncing texting activity…")
                    .font(.subheadline)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine)
        } else if let error = syncStatus.errorMessage {
            VStack(alignment: .leading, spacing: 10) {
                Label("Changes are saved on this device", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Retry sync") {
                    Task { await sync() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private var mostRecentSection: some View {
        if let latest = activeEvents.first, let habit = latest.habit {
            VStack(alignment: .leading, spacing: 8) {
                Text("MOST RECENT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(habit.name)
                    .font(.title2.weight(.semibold))

                if shouldShowTimeSince(for: habit) {
                    Text(HabitFormatting.relative(latest.occurredAt))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                }

                Text(HabitFormatting.timestamp(latest.occurredAt))
                    .font(shouldShowTimeSince(for: habit) ? .subheadline : .title3.weight(.medium))
                    .foregroundStyle(shouldShowTimeSince(for: habit) ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .combine)
        } else {
            ContentUnavailableView {
                Label("No entries yet", systemImage: "clock")
            } description: {
                Text("Add an entry to start the timeline.")
            } actions: {
                Button("Add an entry") {
                    showingLog = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(activeHabits.isEmpty)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Habits")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(activeHabits.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if activeHabits.isEmpty {
                Button {
                    showingAddHabit = true
                } label: {
                    Label("Add your first habit", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .buttonStyle(.plain)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 1) {
                    ForEach(activeHabits) { habit in
                        NavigationLink {
                            HabitDetailView(habit: habit)
                        } label: {
                            HabitRow(
                                habit: habit,
                                showsTimeSince: shouldShowTimeSince(for: habit)
                            )
                        }
                        .buttonStyle(.plain)

                        if habit.id != activeHabits.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func sync() async {
        guard SyncCredentials.isConfigured else {
            showingSyncSettings = true
            return
        }
        await SyncCoordinator.syncIfConfigured(context: modelContext)
        syncError = syncStatus.errorMessage
    }

    private func exportCSV() {
        exportType = .commaSeparatedText
        exportFilename = "Tali all data \(exportDate)"
        exportDocument = TaliExportDocument(data: TaliDataExport.csv(habits: habits, events: events))
        showingExporter = true
    }

    private func exportJSON() {
        isPreparingExport = true
        Task {
            do {
                let localData = try TaliDataExport.json(habits: habits, events: events)
                let serverData: Data?
                if SyncCredentials.isConfigured {
                    serverData = try await TaliAccountService.exportData(
                        endpoint: SyncCredentials.endpoint,
                        token: SyncCredentials.token()
                    )
                } else {
                    serverData = nil
                }
                exportType = .json
                exportFilename = "Tali complete archive \(exportDate)"
                exportDocument = TaliExportDocument(
                    data: try TaliCompleteDataExport.archive(
                        localData: localData,
                        serverData: serverData
                    )
                )
                showingExporter = true
            } catch {
                exportError = error.localizedDescription
            }
            isPreparingExport = false
        }
    }

    private var exportDate: String {
        Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }

    private func shouldShowTimeSince(for habit: Habit) -> Bool {
        TimeSinceVisibility.isVisible(
            globally: showsTimeSince,
            hiddenHabitIDs: hiddenTimeSinceHabitIDs,
            for: habit.id
        )
    }
}

private struct ArchivedHabitsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.name) private var habits: [Habit]

    @State private var errorMessage: String?

    private var archivedHabits: [Habit] {
        habits.filter(\.isArchived)
    }

    var body: some View {
        NavigationStack {
            List {
                if archivedHabits.isEmpty {
                    ContentUnavailableView(
                        "No archived habits",
                        systemImage: "archivebox",
                        description: Text("Archived habits remain here with their full history.")
                    )
                } else {
                    Section {
                        ForEach(archivedHabits) { habit in
                            Button {
                                restore(habit)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(habit.name)
                                            .foregroundStyle(.primary)
                                        Text("\(habit.events.filter { !$0.isVoided }.count) entries")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                    Spacer()
                                    Text("Restore")
                                }
                            }
                            .accessibilityHint("Returns this habit to the dashboard")
                        }
                    } footer: {
                        Text("Restoring a habit also makes its text commands active again.")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }
                }
            }
            .navigationTitle("Archived Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func restore(_ habit: Habit) {
        do {
            try HabitEngine(context: modelContext).setArchived(habit, false)
            Task { await SyncCoordinator.syncIfConfigured(context: modelContext) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct HabitRow: View {
    let habit: Habit
    let showsTimeSince: Bool

    private var latest: HabitEvent? {
        habit.events
            .filter { !$0.isVoided }
            .max { $0.occurredAt < $1.occurredAt }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color(.tertiarySystemFill), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(latest.map { event in
                    showsTimeSince
                        ? HabitFormatting.relative(event.occurredAt)
                        : HabitFormatting.timestamp(event.occurredAt)
                } ?? "Never logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows habit history")
    }
}
