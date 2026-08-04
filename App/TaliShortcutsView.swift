import AppIntents
import SwiftUI

struct TaliShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSiriTipVisible = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Log a habit")
                                .font(.headline)
                            Text("Choose a habit and time from Shortcuts, Siri, or the Action button.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }

                    ShortcutsLink()
                        .accessibilityIdentifier("shortcuts.open")
                } footer: {
                    Text("This opens Tali’s page in Apple Shortcuts.")
                }

                Section("Siri") {
                    SiriTipView(intent: LogHabitIntent(), isVisible: $isSiriTipVisible)
                }
            }
            .navigationTitle("Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                TaliShortcuts.updateAppShortcutParameters()
            }
        }
    }
}
