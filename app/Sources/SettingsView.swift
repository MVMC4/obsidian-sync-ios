import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var access: VaultAccessCoordinator
    @ObservedObject var profiles: SyncProfileManager
    @ObservedObject var engine: SyncthingBridge
    @ObservedObject var session: SyncSessionController
    @ObservedObject var diagnostics: DiagnosticsRecorder
    @ObservedObject var onboarding: OnboardingStore

    let onPickFolder: () -> Void
    let onPair: () -> Void

    @State private var isRunningAccessTest = false
    @State private var accessTestResult: String?
    @State private var diagnosticsURL: URL?
    @State private var diagnosticsError: String?
    @State private var confirmForgetVault = false
    @State private var confirmForgetPairing = false

    private var sessionActive: Bool { session.phase.isActive }

    private var context: RecoveryContext {
        RecoveryContext(
            phase: session.phase,
            peerConnected: session.status?.peerConnected ?? false,
            vaultSelected: access.hasSelection,
            profileConfigured: profiles.profile != nil,
            conflictCount: session.conflicts.count,
            lastError: session.lastError
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    vaultSection
                    pairingSection
                    identitySection
                    recoverySection
                    diagnosticsSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(VaultPalette.parchment.ignoresSafeArea())
            .navigationTitle("Settings & Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .alert("Forget saved vault permission?", isPresented: $confirmForgetVault) {
                Button("Forget", role: .destructive) { access.forgetSelection(); accessTestResult = nil }
                Button("Keep", role: .cancel) {}
            } message: {
                Text("You will need to choose the vault folder again before the next sync. Your notes are not deleted.")
            }
            .alert("Remove computer settings?", isPresented: $confirmForgetPairing) {
                Button("Remove", role: .destructive) { profiles.clear() }
                Button("Keep", role: .cancel) {}
            } message: {
                Text("This removes the saved computer device ID and folder ID. Your vault and notes are untouched.")
            }
        }
    }

    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Selected vault", icon: "folder.fill")
            Text(access.selectedVaultName ?? "No vault selected")
                .font(VaultType.body(.title3, weight: .semibold))
            Text(access.hasSelection ? "Saved permission is stored securely outside the vault."
                                     : "Pick the real Obsidian vault from Files.")
                .font(.footnote).foregroundStyle(VaultPalette.muted)
            HStack(spacing: 10) {
                VaultPillButton(title: access.hasSelection ? "Change vault" : "Choose vault",
                                systemImage: "folder.badge.plus", style: .outline,
                                disabled: sessionActive, action: onPickFolder)
                VaultPillButton(title: isRunningAccessTest ? "Testing" : "Test access",
                                systemImage: "stethoscope", style: .teal,
                                disabled: !access.hasSelection || isRunningAccessTest || sessionActive,
                                action: runAccessTest)
            }
            if let accessTestResult {
                Label(accessTestResult,
                      systemImage: accessTestResult.hasPrefix("Passed") ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(accessTestResult.hasPrefix("Passed") ? VaultPalette.teal : VaultPalette.orange)
            }
            Button(role: .destructive) { confirmForgetVault = true } label: {
                Label("Forget saved vault permission", systemImage: "trash")
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(VaultPalette.orange)
            .disabled(sessionActive || !access.hasSelection)
            .opacity(sessionActive || !access.hasSelection ? 0.4 : 1)
        }
        .vaultPanel()
    }

    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Computer settings", icon: "desktopcomputer")
            Text(profiles.profile?.peerName ?? "Not configured")
                .font(VaultType.body(.title3, weight: .semibold))
            Text(profiles.profile.map {
                "Saved · Folder ID: \($0.folderID) · Run Sync now to verify"
            } ?? "Add the computer's device ID and shared Folder ID.")
                .font(.footnote).foregroundStyle(VaultPalette.muted)
            HStack(spacing: 10) {
                VaultPillButton(title: profiles.profile == nil ? "Configure" : "Edit settings",
                                systemImage: "link", style: .lilac,
                                disabled: sessionActive, action: onPair)
            }
            if profiles.profile != nil {
                Button(role: .destructive) { confirmForgetPairing = true } label: {
                    Label("Remove pairing profile", systemImage: "trash")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(VaultPalette.orange)
                .disabled(sessionActive)
                .opacity(sessionActive ? 0.4 : 1)
            }
        }
        .vaultPanel()
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("This iPad", icon: "ipad")
            if let deviceID = engine.deviceID {
                DeviceIDQRCode(deviceID: deviceID).frame(maxWidth: .infinity)
                Text(deviceID)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .center)
                VaultPillButton(title: "Copy device ID", systemImage: "doc.on.doc",
                                style: .outline) {
                    UIPasteboard.general.string = deviceID
                }
            } else {
                Text("Preparing device identity").font(.footnote).foregroundStyle(VaultPalette.muted)
            }
        }
        .vaultPanel()
    }

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Recovery guidance", icon: "wrench.and.screwdriver.fill")
            let items = RecoveryGuidance.scenarios(for: context)
            if items.isEmpty {
                Label("Nothing needs attention right now.", systemImage: "checkmark.seal")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(VaultPalette.teal)
            } else {
                ForEach(items) { scenario in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(scenario.title).font(.subheadline.weight(.semibold))
                        ForEach(scenario.steps, id: \.self) { step in
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(VaultPalette.orange).frame(width: 5, height: 5)
                                    .padding(.top, 7)
                                Text(step).font(.footnote).foregroundStyle(VaultPalette.ink.opacity(0.8))
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(VaultPalette.parchment))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(VaultPalette.hairline, lineWidth: 1))
                }
            }
        }
        .vaultPanel()
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Session log & diagnostics", icon: "doc.badge.gearshape")
            if diagnostics.events.isEmpty {
                Text("No sync attempt has run yet. Session steps will appear here after you tap Sync now.")
                    .font(.footnote).foregroundStyle(VaultPalette.muted)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(diagnostics.events.suffix(8).reversed().enumerated()), id: \.offset) { _, event in
                        diagnosticRow(event)
                        if event.timestamp != diagnostics.events.suffix(8).first?.timestamp {
                            Divider().overlay(VaultPalette.hairline)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(VaultPalette.parchment))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(VaultPalette.hairline, lineWidth: 1))
            }
            Text("The report includes session phases and sync counts only. Vault names and paths, device IDs, peer labels, folder IDs, addresses, keys, and raw errors are excluded.")
                .font(.footnote).foregroundStyle(VaultPalette.muted)
            VaultPillButton(title: "Prepare report", systemImage: "square.and.arrow.up",
                            style: .primary, disabled: sessionActive,
                            action: prepareDiagnostics)
            if let diagnosticsURL {
                ShareLink(item: diagnosticsURL) {
                    Label("Share redacted report", systemImage: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(VaultPalette.teal))
                        .foregroundStyle(VaultPalette.onInk)
                }
            }
            if let diagnosticsError {
                Text(diagnosticsError).font(.footnote).foregroundStyle(VaultPalette.orange)
            }
        }
        .vaultPanel()
    }

    private func diagnosticRow(_ event: DiagnosticEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: diagnosticIcon(event))
                .foregroundStyle(event.outcome == .success ? VaultPalette.teal : VaultPalette.muted)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(readablePhase(event.phase))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(VaultPalette.ink)
                if let status = event.status {
                    Text(status.peerConnected
                         ? "Computer connected · \(Int(min(status.localCompletionPct, status.remoteCompletionPct)))% complete"
                         : "Computer not connected yet")
                        .font(.caption)
                        .foregroundStyle(VaultPalette.muted)
                }
            }
            Spacer(minLength: 8)
            Text(event.timestamp, style: .time)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(VaultPalette.muted)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func readablePhase(_ rawValue: String) -> String {
        switch SyncSessionPhase(rawValue: rawValue) {
        case .idle: return "Idle"
        case .acquiringVaultAccess: return "Opened vault permission"
        case .startingEngine: return "Started sync engine"
        case .configuring: return "Applied computer settings"
        case .scanning: return "Scanning vault"
        case .waitingForPeer: return "Waiting for computer"
        case .synchronizing: return "Synchronizing files"
        case .verifyingCompletion: return "Verifying both devices"
        case .stoppingEngine: return "Stopped sync engine"
        case .complete: return "Verified up to date"
        case .completeWithConflicts: return "Completed with conflicts"
        case .failed: return "Sync failed"
        case .cancelled: return "Sync stopped"
        case nil: return "Unknown session event"
        }
    }

    private func diagnosticIcon(_ event: DiagnosticEvent) -> String {
        switch event.outcome {
        case .success: return "checkmark.circle.fill"
        case .successWithConflicts: return "exclamationmark.triangle.fill"
        case .cancelled: return "stop.circle.fill"
        case .timeout, .vaultAccessFailure, .configurationFailure, .engineFailure:
            return "xmark.octagon.fill"
        case nil: return "circle.fill"
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("About", icon: "info.circle")
            Text("Vault Sync \(appVersion) (\(appBuild))")
                .font(.footnote.weight(.semibold))
            Text("An open-source, MIT-licensed foreground Syncthing client for Obsidian. Not affiliated with Obsidian, Syncthing, or any referenced design.")
                .font(.footnote).foregroundStyle(VaultPalette.muted)
            VaultPillButton(title: "Replay introduction", systemImage: "sparkles",
                            style: .lilac) {
                onboarding.replay()
                dismiss()
            }
        }
        .vaultPanel()
    }

    private func sectionTitle(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(VaultType.body(.headline, weight: .bold))
            .foregroundStyle(VaultPalette.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private func runAccessTest() {
        isRunningAccessTest = true
        defer { isRunningAccessTest = false }
        do {
            let s = try access.openSession()
            defer { s.close() }
            let report = try VaultSpikeRunner().run(in: s.url)
            accessTestResult = "Passed: \(report.completedOperations.joined(separator: ", "))."
        } catch {
            accessTestResult = "Failed: \(error.localizedDescription)"
        }
    }

    private func prepareDiagnostics() {
        diagnosticsError = nil
        do {
            let data = try DiagnosticsReportBuilder.makeData(
                profile: profiles.profile,
                vaultSelected: access.hasSelection,
                engineState: engine.state,
                phase: session.phase,
                status: session.status,
                conflictCount: session.conflicts.count,
                events: diagnostics.events
            )
            diagnosticsURL = try DiagnosticsExportWriter().write(data)
        } catch {
            diagnosticsURL = nil
            diagnosticsError = "The redacted diagnostics report could not be created."
        }
    }
}
