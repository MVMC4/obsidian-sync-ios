import SwiftUI

struct VaultAccessView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var access: VaultAccessCoordinator
    @StateObject private var engine: SyncthingBridge
    @StateObject private var profiles: SyncProfileManager
    @StateObject private var session: SyncSessionController

    @State private var isPickingFolder = false
    @State private var isShowingPairing = false
    @State private var isRunningAccessTest = false
    @State private var accessTestResult: String?
    @State private var actionError: String?

    @MainActor
    init() {
        let access = VaultAccessCoordinator()
        let engine = SyncthingBridge()
        _access = StateObject(wrappedValue: access)
        _engine = StateObject(wrappedValue: engine)
        _profiles = StateObject(wrappedValue: SyncProfileManager())
        _session = StateObject(
            wrappedValue: SyncSessionController(engine: engine, vaultAccess: access)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    syncCard
                    statusCard
                    conflictCard
                    setupGrid
                    diagnosticsCard
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .background(background)
            .navigationTitle("Vault Sync")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                try? engine.prepare()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active, session.phase.isActive {
                    session.cancel()
                }
            }
            .sheet(isPresented: $isPickingFolder) {
                FolderPicker(
                    onSelection: { url in
                        isPickingFolder = false
                        access.rememberSelection(url)
                        accessTestResult = nil
                    },
                    onCancel: { isPickingFolder = false }
                )
            }
            .sheet(isPresented: $isShowingPairing) {
                PairingView(
                    existingProfile: profiles.profile,
                    localDeviceID: engine.deviceID,
                    onSave: profiles.save
                )
                .presentationDetents([.large])
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                Color.indigo.opacity(0.08),
                Color(uiColor: .systemGroupedBackground),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.indigo)
                Text("Your notes, directly synced")
                    .font(.largeTitle.bold())
            }
            Text("Run a focused Syncthing session, wait for a verified result, then return to Obsidian.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var syncCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryStatusTitle)
                        .font(.title2.bold())
                    Text(primaryStatusDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: phaseIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(phaseColor)
                    .symbolEffect(.pulse, isActive: session.phase.isActive)
            }

            if let status = session.status {
                VStack(spacing: 8) {
                    ProgressView(value: min(status.localCompletionPct, status.remoteCompletionPct), total: 100)
                        .tint(.indigo)
                    HStack {
                        Text(status.peerConnected ? "Peer connected" : "Waiting for peer")
                        Spacer()
                        Text("\(Int(min(status.localCompletionPct, status.remoteCompletionPct)))%")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Button(action: primaryAction) {
                Label(
                    session.phase.isActive ? "Stop sync" : "Sync now",
                    systemImage: session.phase.isActive ? "stop.fill" : "arrow.triangle.2.circlepath"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(session.phase.isActive ? .red : .indigo)
            .disabled(!session.phase.isActive && !isReadyToSync)

            if !isReadyToSync, !session.phase.isActive {
                Text("Choose a vault and pair a computer before syncing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let error = session.lastError ?? actionError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var statusCard: some View {
        if let status = session.status {
            HStack(spacing: 12) {
                metric("Local need", value: status.needItems == 0 ? "None" : "\(status.needItems) items")
                Divider()
                metric("Remote need", value: status.remoteNeedItems == 0 ? "None" : "\(status.remoteNeedItems) items")
                Divider()
                metric("Folder", value: status.folderState.capitalized)
            }
            .frame(maxWidth: .infinity)
            .cardStyle()
        }
    }

    @ViewBuilder
    private var conflictCard: some View {
        if !session.conflicts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Conflict copies need review", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("Syncthing preserved competing edits. Open these files in the vault and merge the version you want to keep.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(session.conflicts.prefix(5), id: \.self) { path in
                    Text(path)
                        .font(.caption.monospaced())
                        .lineLimit(2)
                }
                if session.conflicts.count > 5 {
                    Text("And \(session.conflicts.count - 5) more…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .cardStyle()
        }
    }

    private var setupGrid: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                vaultCard
                peerCard
            }
            VStack(spacing: 16) {
                vaultCard
                peerCard
            }
        }
    }

    private var vaultCard: some View {
        setupCard(
            title: "Vault",
            value: access.selectedVaultName ?? "Not selected",
            detail: access.hasSelection ? "Permission saved" : "Choose a disposable vault first",
            icon: "folder.fill",
            actionTitle: access.hasSelection ? "Change" : "Choose"
        ) {
            isPickingFolder = true
        }
    }

    private var peerCard: some View {
        setupCard(
            title: "Computer",
            value: profiles.profile?.peerName ?? "Not paired",
            detail: profiles.profile.map { "Folder ID: \($0.folderID)" } ?? "Enter the existing Syncthing IDs",
            icon: "desktopcomputer",
            actionTitle: profiles.profile == nil ? "Pair" : "Edit"
        ) {
            isShowingPairing = true
        }
    }

    private var diagnosticsCard: some View {
        DisclosureGroup("Permission diagnostics") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Creates, reads, edits, renames, and deletes a temporary Markdown file. Run again after force-quitting to verify the saved folder permission.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(isRunningAccessTest ? "Testing…" : "Run vault access test") {
                    runAccessTest()
                }
                .buttonStyle(.bordered)
                .disabled(!access.hasSelection || isRunningAccessTest || session.phase.isActive)

                if let accessTestResult {
                    Text(accessTestResult)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(accessTestResult.hasPrefix("Passed") ? .green : .red)
                }

                if let deviceID = engine.deviceID {
                    Text("This iPad")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(deviceID)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                }
            }
            .padding(.top, 12)
        }
        .cardStyle()
    }

    private var isReadyToSync: Bool {
        access.hasSelection && profiles.profile != nil && engine.deviceID != nil
    }

    private var primaryStatusTitle: String {
        switch session.phase {
        case .idle: return "Ready when you are"
        case .acquiringVaultAccess: return "Opening vault"
        case .startingEngine: return "Starting secure sync"
        case .configuring: return "Applying settings"
        case .scanning: return "Scanning notes"
        case .waitingForPeer: return "Waiting for computer"
        case .synchronizing: return "Syncing changes"
        case .verifyingCompletion: return "Verifying both devices"
        case .stoppingEngine: return "Finishing safely"
        case .complete: return "Vault is up to date"
        case .completeWithConflicts: return "Synced with conflicts"
        case .failed: return "Sync needs attention"
        case .cancelled: return "Sync stopped"
        }
    }

    private var primaryStatusDetail: String {
        switch session.phase {
        case .idle: return "Manual foreground sync"
        case .complete: return "The engine stopped and vault access was released."
        case .completeWithConflicts: return "The engine stopped safely. Review the preserved conflict copies below."
        case .failed: return "Review the message below and try again."
        case .cancelled: return "No sync process is running."
        default: return "Keep this app open until the session finishes."
        }
    }

    private var phaseIcon: String {
        switch session.phase {
        case .complete: return "checkmark.circle.fill"
        case .completeWithConflicts: return "exclamationmark.triangle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "stop.circle.fill"
        case .idle: return "circle.dotted"
        default: return "arrow.triangle.2.circlepath"
        }
    }

    private var phaseColor: Color {
        switch session.phase {
        case .complete: return .green
        case .completeWithConflicts: return .orange
        case .failed: return .red
        case .cancelled: return .orange
        default: return .indigo
        }
    }

    private func primaryAction() {
        actionError = nil
        if session.phase.isActive {
            session.cancel()
            return
        }
        guard let profile = profiles.profile else {
            isShowingPairing = true
            return
        }
        do {
            try session.start(profile: profile)
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func runAccessTest() {
        isRunningAccessTest = true
        defer { isRunningAccessTest = false }

        do {
            let accessSession = try access.openSession()
            defer { accessSession.close() }
            let report = try VaultSpikeRunner().run(in: accessSession.url)
            accessTestResult = "Passed: \(report.completedOperations.joined(separator: ", "))."
        } catch {
            accessTestResult = "Failed: \(error.localizedDescription)"
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setupCard(
        title: String,
        value: String,
        detail: String,
        icon: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.indigo)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
        .cardStyle()
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}
