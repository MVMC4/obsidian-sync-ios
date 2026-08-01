import SwiftUI

struct VaultAccessView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var access: VaultAccessCoordinator
    @StateObject private var engine: SyncthingBridge
    @StateObject private var profiles: SyncProfileManager
    @StateObject private var diagnostics: DiagnosticsRecorder
    @StateObject private var session: SyncSessionController
    @StateObject private var onboarding: OnboardingStore

    @State private var isPickingFolder = false
    @State private var isShowingPairing = false
    @State private var isShowingSettings = false
    @State private var actionError: String?

    @MainActor
    init() {
        let access = VaultAccessCoordinator()
        let engine = SyncthingBridge()
        let diagnostics = DiagnosticsRecorder()
        _access = StateObject(wrappedValue: access)
        _engine = StateObject(wrappedValue: engine)
        _profiles = StateObject(wrappedValue: SyncProfileManager())
        _diagnostics = StateObject(wrappedValue: diagnostics)
        _session = StateObject(wrappedValue: SyncSessionController(
            engine: engine, vaultAccess: access, diagnostics: diagnostics
        ))
        _onboarding = StateObject(wrappedValue: OnboardingStore())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    EditorialHero().vaultReveal("hero")
                    DottedFlow()
                    syncHero.vaultReveal("sync")
                    if !session.conflicts.isEmpty { conflictCard.vaultReveal("conflict") }
                    setupRow.vaultReveal("setup")
                    activityCard.vaultReveal("activity")
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background(VaultPalette.parchment.ignoresSafeArea())
            .navigationTitle("Vault Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings and recovery")
                    .accessibilityHint("Open vault, pairing, diagnostics, and recovery actions")
                }
            }
            .task { try? engine.prepare() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active, session.phase.isActive { session.cancel() }
            }
            .fullScreenCover(isPresented: Binding(
                get: { onboarding.shouldShow },
                set: { if !$0 { onboarding.markComplete() } }
            )) {
                OnboardingView(onFinish: onboarding.markComplete)
            }
            .sheet(isPresented: $isPickingFolder) {
                FolderPicker(
                    onSelection: { url in isPickingFolder = false; access.rememberSelection(url) },
                    onCancel: { isPickingFolder = false }
                )
            }
            .sheet(isPresented: $isShowingPairing) {
                PairingView(
                    existingProfile: profiles.profile,
                    localDeviceID: engine.deviceID,
                    normalizeDeviceID: engine.normalizeDeviceID,
                    onSave: profiles.save
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(
                    access: access, profiles: profiles, engine: engine,
                    session: session, diagnostics: diagnostics, onboarding: onboarding,
                    onPickFolder: { isShowingSettings = false; isPickingFolder = true },
                    onPair: { isShowingSettings = false; isShowingPairing = true }
                )
            }
        }
    }

    private var syncHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        VaultBadge(text: phaseBadge, tint: phaseTint, icon: phaseIcon)
                        if session.phase.isActive {
                            VaultBadge(text: "foreground only", tint: VaultPalette.muted)
                        }
                    }
                    Text(primaryStatusTitle)
                        .font(VaultType.display(size: 30, weight: .black))
                        .foregroundStyle(VaultPalette.onInk)
                        .accessibilityAddTraits(.isHeader)
                    Text(primaryStatusDetail)
                        .font(.subheadline)
                        .foregroundStyle(VaultPalette.onInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                SyncMark(active: session.phase.isActive)
            }
            if let status = session.status {
                VStack(spacing: 8) {
                    ProgressView(value: min(status.localCompletionPct, status.remoteCompletionPct), total: 100)
                        .tint(VaultPalette.orange)
                    HStack {
                        Label(status.peerConnected ? "Peer connected" : "Waiting for peer",
                              systemImage: status.peerConnected ? "link.circle.fill" : "link.circle")
                            .foregroundStyle(status.peerConnected ? VaultPalette.teal : VaultPalette.orange)
                        Spacer()
                        Text("\(Int(min(status.localCompletionPct, status.remoteCompletionPct)))%")
                            .monospacedDigit().foregroundStyle(VaultPalette.onInk)
                    }
                    .font(.caption.weight(.semibold))
                    .accessibilityElement(children: .combine)
                }
            }
            VaultPillButton(
                title: session.phase.isActive ? "Stop sync" : "Sync now",
                systemImage: session.phase.isActive ? "stop.fill" : "arrow.triangle.2.circlepath",
                style: session.phase.isActive ? .orange : .lilac,
                disabled: !session.phase.isActive && !isReadyToSync,
                action: primaryAction
            )
            if !isReadyToSync, !session.phase.isActive {
                Text("Choose a vault and pair a computer in Settings before syncing.")
                    .font(.footnote).foregroundStyle(VaultPalette.onInkMuted)
            }
            if let error = session.lastError ?? actionError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(VaultPalette.orange)
            }
        }
        .vaultPanel(ink: true)
        .accessibilityElement(children: .contain)
    }

    private var conflictCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Conflict copies need review", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(VaultPalette.orange)
                Spacer()
                VaultBadge(text: "\(session.conflicts.count)", tint: VaultPalette.orange)
            }
            Text("Syncthing preserved competing edits. Open them in Obsidian and keep the version you want.")
                .font(.footnote).foregroundStyle(VaultPalette.muted)
            ForEach(session.conflicts.prefix(4), id: \.self) { path in
                Text(path).font(.caption.monospaced()).lineLimit(2)
            }
            VaultPillButton(title: "Open recovery", systemImage: "wrench.and.screwdriver.fill",
                            style: .outline) { isShowingSettings = true }
        }
        .vaultPanel()
    }

    private var setupRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) { vaultCard; peerCard }
            VStack(spacing: 16) { vaultCard; peerCard }
        }
    }

    private var vaultCard: some View {
        setupCard(title: "Vault", value: access.selectedVaultName ?? "Not selected",
                  detail: access.hasSelection ? "Permission saved" : "Choose from Files",
                  icon: "folder.fill", tint: VaultPalette.orange,
                  actionTitle: access.hasSelection ? "Change" : "Choose") {
            isPickingFolder = true
        }
    }

    private var peerCard: some View {
        setupCard(title: "Computer", value: profiles.profile?.peerName ?? "Not paired",
                  detail: profiles.profile.map { "Folder \($0.folderID)" } ?? "Pair a device",
                  icon: "desktopcomputer", tint: VaultPalette.lilac,
                  actionTitle: profiles.profile == nil ? "Pair" : "Edit") {
            isShowingPairing = true
        }
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Recent activity", systemImage: "clock.arrow.circlepath")
                    .font(VaultType.body(.headline, weight: .bold))
                    .foregroundStyle(VaultPalette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !session.activity.isEmpty {
                    VaultBadge(text: "\(session.activity.count)", tint: VaultPalette.teal)
                }
            }
            if session.activity.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.system(size: 30)).foregroundStyle(VaultPalette.muted)
                    Text("No file activity yet.")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(VaultPalette.ink)
                    Text("Start a sync to see incoming and outgoing notes here, with the newest first.")
                        .font(.footnote).foregroundStyle(VaultPalette.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .accessibilityElement(children: .combine)
            } else {
                VStack(spacing: 0) {
                    ForEach(session.activity.prefix(12)) { item in
                        activityRow(item)
                        if item.id != session.activity.prefix(12).last?.id {
                            Divider().overlay(VaultPalette.hairline)
                        }
                    }
                }
            }
        }
        .vaultPanel()
    }

    private func activityRow(_ item: SyncActivityItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill((item.isIncoming ? VaultPalette.teal : VaultPalette.orange).opacity(0.16))
                Image(systemName: item.isIncoming ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundStyle(item.isIncoming ? VaultPalette.teal : VaultPalette.orange)
            }
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName).font(.subheadline.weight(.semibold))
                    .foregroundStyle(VaultPalette.ink).lineLimit(1)
                if !item.parentPath.isEmpty {
                    Text(item.parentPath).font(.caption).foregroundStyle(VaultPalette.muted).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                VaultBadge(text: item.isFailed ? "failed" : item.action,
                           tint: item.isFailed ? VaultPalette.orange : VaultPalette.ink.opacity(0.7))
                Text(relativeTime(item.date)).font(.caption2).foregroundStyle(VaultPalette.muted)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.isIncoming ? "Incoming" : "Outgoing") \(item.fileName), \(item.action), \(item.result)")
    }

    private func setupCard(title: String, value: String, detail: String, icon: String,
                           tint: Color, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon).font(.headline).foregroundStyle(VaultPalette.ink)
                Spacer()
                Circle().fill(tint).frame(width: 10, height: 10)
            }
            Text(value).font(VaultType.body(.title3, weight: .bold)).lineLimit(1)
                .foregroundStyle(VaultPalette.ink)
            Text(detail).font(.footnote).foregroundStyle(VaultPalette.muted).lineLimit(2)
            VaultPillButton(title: actionTitle, style: .outline, action: action)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vaultPanel()
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
        case .idle: return "A manual foreground session, verified on both sides."
        case .complete: return "The engine stopped and vault access was released."
        case .completeWithConflicts: return "Review the preserved conflict copies below."
        case .failed: return "Review recovery guidance in Settings."
        case .cancelled: return "No sync process is running."
        default: return "Keep this app open until the session finishes."
        }
    }

    private var phaseBadge: String {
        switch session.phase {
        case .complete: return "verified"
        case .completeWithConflicts: return "conflicts"
        case .failed: return "attention"
        case .cancelled: return "stopped"
        case .idle: return "idle"
        default: return "syncing"
        }
    }

    private var phaseIcon: String {
        switch session.phase {
        case .complete: return "checkmark.seal.fill"
        case .completeWithConflicts, .failed: return "exclamationmark.triangle.fill"
        case .cancelled: return "stop.circle.fill"
        case .idle: return "circle.dotted"
        default: return "arrow.triangle.2.circlepath"
        }
    }

    private var phaseTint: Color {
        switch session.phase {
        case .complete: return VaultPalette.teal
        case .completeWithConflicts, .failed, .cancelled: return VaultPalette.orange
        default: return VaultPalette.lilac
        }
    }

    private func primaryAction() {
        actionError = nil
        if session.phase.isActive { session.cancel(); return }
        guard let profile = profiles.profile else { isShowingPairing = true; return }
        do { try session.start(profile: profile) }
        catch { actionError = error.localizedDescription }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }
}
