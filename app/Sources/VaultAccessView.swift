import SwiftUI

struct VaultAccessView: View {
    @StateObject private var access = VaultAccessCoordinator()
    @StateObject private var engine = SyncthingBridge()
    @State private var isPickingFolder = false
    @State private var isRunning = false
    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    engineCard
                    selectionCard
                    testCard
                }
                .frame(maxWidth: 680)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Vault Access Lab")
            .task {
                try? engine.prepare()
            }
            .sheet(isPresented: $isPickingFolder) {
                FolderPicker(
                    onSelection: { url in
                        isPickingFolder = false
                        access.rememberSelection(url)
                        resultMessage = nil
                    },
                    onCancel: { isPickingFolder = false }
                )
            }
        }
    }

    private var engineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Embedded sync engine", systemImage: "checkmark.seal")
                .font(.headline)

            if let deviceID = engine.deviceID {
                Text("Core ready")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)
                Text(deviceID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } else if let error = engine.lastError {
                Label(error, systemImage: "xmark.octagon.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                ProgressView("Preparing device identity…")
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.indigo)
            Text("Prove vault access first")
                .font(.largeTitle.bold())
            Text("Choose a disposable Obsidian vault. This test briefly creates, reads, edits, renames, and deletes a Markdown file using coordinated iPadOS file access.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Selected vault", systemImage: "folder")
                .font(.headline)

            Text(access.selectedVaultName ?? "No vault selected")
                .font(.title3.weight(.medium))

            Button {
                isPickingFolder = true
            } label: {
                Label(access.hasSelection ? "Choose another vault" : "Choose vault", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if access.hasSelection {
                Button("Forget saved permission", role: .destructive) {
                    access.forgetSelection()
                    resultMessage = nil
                }
                .font(.subheadline)
            }

            if let error = access.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Physical-device test", systemImage: "ipad")
                .font(.headline)

            Text("Run once, force-quit the app, reopen it, and run again without reselecting the vault. Then verify in Obsidian that no test folder remains.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: runAccessTest) {
                HStack {
                    if isRunning {
                        ProgressView()
                    }
                    Text(isRunning ? "Testing access…" : "Run access test")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(!access.hasSelection || isRunning)

            if let resultMessage {
                Label(resultMessage, systemImage: resultMessage.hasPrefix("Passed") ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(resultMessage.hasPrefix("Passed") ? .green : .red)
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private func runAccessTest() {
        isRunning = true
        defer { isRunning = false }

        do {
            let session = try access.openSession()
            defer { session.close() }
            let report = try VaultSpikeRunner().run(in: session.url)
            resultMessage = "Passed: \(report.completedOperations.joined(separator: ", "))."
        } catch {
            resultMessage = "Failed: \(error.localizedDescription)"
        }
    }
}
