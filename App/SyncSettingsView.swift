import HabitCore
import SwiftData
import SwiftUI
import UIKit

struct SyncSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var endpoint = SyncCredentials.defaultEndpoint
    @State private var privateKey = ""
    @State private var isConnected = false
    @State private var authenticationMethod = SyncCredentials.AuthenticationMethod.privateKey
    @State private var account: TaliAccountSummary?
    @State private var pairingCode: TaliPairingCode?
    @State private var sessions: [TaliSessionSummary] = []
    @State private var isWorking = false
    @State private var showingDisconnectAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    private var canConnectWithPrivateKey: Bool {
        !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !privateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                if !PersistenceController.isSharedContainerAvailable {
                    Section {
                        Label(
                            "This simulator is using local app storage.",
                            systemImage: "externaldrive.badge.exclamationmark"
                        )
                        .foregroundStyle(.secondary)
                    } footer: {
                        Text("The Messages extension won’t share data until the App Group is available in a signed build.")
                    }
                }

                if isConnected {
                    connectedContent
                } else {
                    setupContent
                }
            }
            .navigationTitle("Texting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                endpoint = SyncCredentials.endpoint
                isConnected = SyncCredentials.isConfigured
                authenticationMethod = SyncCredentials.authenticationMethod
                if isConnected && authenticationMethod == .apple {
                    await refreshAccount()
                }
            }
            .alert("Disconnect texting?", isPresented: $showingDisconnectAlert) {
                Button("Disconnect", role: .destructive) { disconnect() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Habit data stays on this device, but texts will not sync until you reconnect.")
            }
            .alert("Delete account and server data?", isPresented: $showingDeleteAccountAlert) {
                Button("Delete Account", role: .destructive) {
                    deleteAccount()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes the server copy of your habits, entries, texts, pairings, and sessions. Data saved on this device remains available locally.")
            }
        }
    }

    @ViewBuilder
    private var setupContent: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Connect Tali to texting", systemImage: "message.badge.waveform.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Text("Sign in to keep your data separate, then pair the phone number you’ll use to text Tali.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)

            TaliAppleSignInButton(isWorking: isWorking) { identityToken, nonce in
                signIn(identityToken: identityToken, nonce: nonce)
            } failure: { message in
                errorMessage = message
            }

            statusRows
        } footer: {
            Text("Signing in only connects syncing and texting. Tali remains usable on this device without an account.")
        }

        Section("How it works") {
            LabeledContent("1", value: "Continue with Apple")
            LabeledContent("2", value: "Pair your phone once")
            LabeledContent("3", value: "Text a habit name to log it")
        }

        Section {
            DisclosureGroup {
                SecureField("Private connection key", text: $privateKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .privacySensitive()

                TextField("Server address", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                Button {
                    connectWithPrivateKey()
                } label: {
                    HStack {
                        Text(isWorking ? "Connecting…" : "Connect with private key")
                        Spacer()
                        if isWorking { ProgressView() }
                    }
                }
                .disabled(!canConnectWithPrivateKey)

                Button("Use Tali’s default server") {
                    endpoint = SyncCredentials.defaultEndpoint
                }
                .disabled(endpoint == SyncCredentials.defaultEndpoint)
            } label: {
                Label("Advanced", systemImage: "wrench.and.screwdriver")
            }
        } footer: {
            Text("Private keys are for local development and existing single-user installations.")
        }
    }

    @ViewBuilder
    private var connectedContent: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    authenticationMethod == .apple ? "Tali account connected" : "Texting is connected",
                    systemImage: "link.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(.blue)
                Text("Incoming habit messages appear after Tali syncs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }

        if authenticationMethod == .apple && account?.paired != true {
            pairingSection
        } else {
            Section("Text Tali") {
                LabeledContent("Number", value: SyncCredentials.smsPhoneNumber)
                if let phone = account?.phone {
                    LabeledContent("Paired phone", value: phone)
                }

                Button {
                    openURL(messageURL())
                } label: {
                    Label("Open Messages", systemImage: "message.fill")
                }
            }
        }

        Section {
            Button {
                syncNow()
            } label: {
                HStack {
                    Text(isWorking ? "Syncing…" : "Sync now")
                    Spacer()
                    if isWorking { ProgressView() }
                }
            }
            .disabled(isWorking)

            statusRows
        } footer: {
            Text("Tali also syncs when the app opens and when you pull down on the dashboard.")
        }

        Section("Connection") {
            LabeledContent("Server", value: serverName)
            LabeledContent(
                authenticationMethod == .apple ? "Account" : "Private key",
                value: authenticationMethod == .apple ? "Sign in with Apple" : "Saved in Keychain"
            )

            Button(authenticationMethod == .apple ? "Sign out and disconnect" : "Disconnect texting", role: .destructive) {
                showingDisconnectAlert = true
            }
        }

        if authenticationMethod == .apple {
            sessionsSection

            Section {
                Button("Delete account and server data", role: .destructive) {
                    showingDeleteAccountAlert = true
                }
                .disabled(isWorking)
            } footer: {
                Text("This cannot be undone. Your on-device Tali data is not deleted.")
            }
        }
    }

    private var sessionsSection: some View {
        Section("Devices") {
            if sessions.isEmpty {
                Text("No active sessions found.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(session.deviceName)
                            Spacer()
                            if session.current {
                                Text("This device")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Sign Out", role: .destructive) {
                                    revoke(session)
                                }
                                .disabled(isWorking)
                            }
                        }
                        Text("Last used \(formattedSessionDate(session.lastUsedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .contain)
                }
            }

            Button("Refresh devices") {
                Task { await refreshSessions() }
            }
            .disabled(isWorking)
        }
    }

    private var pairingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pair your phone")
                    .font(.headline)
                Text("This makes sure texts from your number go only to your account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Button {
                openURL(messageURL(body: "START"))
            } label: {
                Label("1. Text START to opt in", systemImage: "message")
            }

            if let pairingCode {
                LabeledContent("Pairing code") {
                    Text(pairingCode.code)
                        .font(.body.monospaced().weight(.semibold))
                        .textSelection(.enabled)
                }

                Button {
                    openURL(messageURL(body: "PAIR \(pairingCode.code)"))
                } label: {
                    Label("2. Text pairing code", systemImage: "link")
                }
            } else {
                Button {
                    createPairingCode()
                } label: {
                    HStack {
                        Label("2. Create pairing code", systemImage: "link")
                        Spacer()
                        if isWorking { ProgressView() }
                    }
                }
                .disabled(isWorking)
            }

            Button("3. Check connection") {
                Task { await refreshAccount(showResult: true) }
            }
            .disabled(isWorking || pairingCode == nil)

            statusRows
        } footer: {
            Text("The pairing code expires after 10 minutes. Carrier review must be complete before Tali can send SMS replies.")
        }
    }

    @ViewBuilder
    private var statusRows: some View {
        if let resultMessage {
            Label(resultMessage, systemImage: "arrow.triangle.2.circlepath.circle.fill")
                .foregroundStyle(.blue)
                .accessibilityLabel("Complete: \(resultMessage)")
                .accessibilityAddTraits(.updatesFrequently)
        }
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Error: \(errorMessage)")
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private var serverName: String {
        URL(string: SyncCredentials.endpoint)?.host ?? SyncCredentials.endpoint
    }

    private func signIn(identityToken: String, nonce: String) {
        isWorking = true
        clearStatus()
        Task {
            do {
                let result = try await TaliAccountService.signIn(
                    endpoint: endpoint,
                    identityToken: identityToken,
                    nonce: nonce,
                    deviceName: UIDevice.current.name
                )
                try SyncCredentials.save(endpoint: endpoint, token: result.token, method: .apple)
                authenticationMethod = .apple
                account = result.account
                isConnected = true
                if result.account.paired {
                    let report = try await TaliSyncService.sync(
                        context: modelContext,
                        endpoint: SyncCredentials.endpoint,
                        token: result.token
                    )
                    SyncCoordinator.recordSuccess()
                    resultMessage = "Synced \(report.habitCount) habits and \(report.eventCount) entries."
                } else {
                    resultMessage = "Signed in. Pair your phone to finish connecting texting."
                }
                await refreshSessions()
            } catch {
                SyncCoordinator.recordFailure(error)
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func connectWithPrivateKey() {
        isWorking = true
        clearStatus()
        Task {
            do {
                let candidateEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
                let candidateToken = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
                let report = try await TaliSyncService.sync(
                    context: modelContext,
                    endpoint: candidateEndpoint,
                    token: candidateToken
                )
                try SyncCredentials.save(endpoint: candidateEndpoint, token: candidateToken, method: .privateKey)
                SyncCoordinator.recordSuccess()
                authenticationMethod = .privateKey
                isConnected = true
                privateKey = ""
                resultMessage = "Synced \(report.habitCount) habits and \(report.eventCount) entries."
            } catch {
                SyncCoordinator.recordFailure(error)
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func createPairingCode() {
        isWorking = true
        clearStatus()
        Task {
            do {
                pairingCode = try await TaliAccountService.createPairingCode(
                    endpoint: SyncCredentials.endpoint,
                    token: SyncCredentials.token()
                )
                resultMessage = "Pairing code created."
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func refreshAccount(showResult: Bool = false) async {
        guard authenticationMethod == .apple else { return }
        isWorking = true
        if showResult { clearStatus() }
        do {
            account = try await TaliAccountService.account(
                endpoint: SyncCredentials.endpoint,
                token: SyncCredentials.token()
            )
            await refreshSessions()
            if account?.paired == true {
                pairingCode = nil
                if showResult {
                    let report = try await TaliSyncService.sync(
                        context: modelContext,
                        endpoint: SyncCredentials.endpoint,
                        token: SyncCredentials.token()
                    )
                    SyncCoordinator.recordSuccess()
                    resultMessage = "Phone connected. Synced \(report.habitCount) habits and \(report.eventCount) entries."
                }
            } else if showResult {
                resultMessage = "No paired phone yet. Send the pairing text, then check again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    private func syncNow() {
        isWorking = true
        clearStatus()
        Task {
            do {
                let report = try await TaliSyncService.sync(
                    context: modelContext,
                    endpoint: SyncCredentials.endpoint,
                    token: SyncCredentials.token()
                )
                SyncCoordinator.recordSuccess()
                resultMessage = "Synced \(report.habitCount) habits and \(report.eventCount) entries."
            } catch {
                SyncCoordinator.recordFailure(error)
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func disconnect() {
        let endpoint = SyncCredentials.endpoint
        let token = SyncCredentials.token()
        let shouldRevoke = authenticationMethod == .apple
        do {
            try SyncCredentials.clear()
            self.endpoint = SyncCredentials.defaultEndpoint
            privateKey = ""
            account = nil
            pairingCode = nil
            sessions = []
            clearStatus()
            isConnected = false
            authenticationMethod = .privateKey
            if shouldRevoke {
                Task { await TaliAccountService.signOut(endpoint: endpoint, token: token) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshSessions() async {
        guard authenticationMethod == .apple, SyncCredentials.isConfigured else { return }
        do {
            sessions = try await TaliAccountService.sessions(
                endpoint: SyncCredentials.endpoint,
                token: SyncCredentials.token()
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revoke(_ session: TaliSessionSummary) {
        isWorking = true
        clearStatus()
        Task {
            do {
                try await TaliAccountService.revokeSession(
                    id: session.id,
                    endpoint: SyncCredentials.endpoint,
                    token: SyncCredentials.token()
                )
                await refreshSessions()
                resultMessage = "Signed out \(session.deviceName)."
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func deleteAccount() {
        isWorking = true
        clearStatus()
        let endpoint = SyncCredentials.endpoint
        let token = SyncCredentials.token()
        Task {
            do {
                try await TaliAccountService.deleteAccount(endpoint: endpoint, token: token)
                try SyncCredentials.clear()
                self.endpoint = SyncCredentials.defaultEndpoint
                isConnected = false
                authenticationMethod = .privateKey
                account = nil
                pairingCode = nil
                sessions = []
                resultMessage = "Account and server data deleted. Local data remains on this device."
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func formattedSessionDate(_ value: String) -> String {
        guard let date = try? Date(value, strategy: .iso8601) else { return value }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func clearStatus() {
        resultMessage = nil
        errorMessage = nil
    }

    private func messageURL(body: String? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "sms"
        components.path = "+14455452123"
        if let body { components.queryItems = [URLQueryItem(name: "body", value: body)] }
        return components.url ?? URL(string: "sms:+14455452123")!
    }
}
