import SwiftUI

struct PairingView: View {
    @Environment(\.dismiss) private var dismiss
    let existingProfile: SyncProfile?
    let localDeviceID: String?
    let normalizeDeviceID: (String) throws -> String
    let onSave: (SyncProfile) throws -> Void

    @State private var peerDeviceID: String
    @State private var peerName: String
    @State private var address: String
    @State private var folderID: String
    @State private var folderLabel: String
    @State private var errorMessage: String?
    @State private var isShowingScanner = false

    init(
        existingProfile: SyncProfile?,
        localDeviceID: String?,
        normalizeDeviceID: @escaping (String) throws -> String,
        onSave: @escaping (SyncProfile) throws -> Void
    ) {
        self.existingProfile = existingProfile
        self.localDeviceID = localDeviceID
        self.normalizeDeviceID = normalizeDeviceID
        self.onSave = onSave
        _peerDeviceID = State(initialValue: existingProfile?.peerDeviceID ?? "")
        _peerName = State(initialValue: existingProfile?.peerName ?? "Desktop")
        _address = State(initialValue: existingProfile?.addresses.first == "dynamic"
            ? "" : existingProfile?.addresses.first ?? "")
        _folderID = State(initialValue: existingProfile?.folderID ?? "")
        _folderLabel = State(initialValue: existingProfile?.folderLabel ?? "Notes")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    explanationCard
                    thisIPadCard
                    peerCard
                    folderCard
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(VaultPalette.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(VaultPalette.orange.opacity(0.12)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(VaultPalette.parchment.ignoresSafeArea())
            .navigationTitle(existingProfile == nil ? "Configure computer" : "Sync settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save settings") { save() }.fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                QRCodeScannerSheet { payload in handleScannedPayload(payload) }
            }
        }
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("What this step does", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(VaultPalette.teal)
            Text("This saves the computer and folder details. It does not connect yet. After saving, return to the dashboard and tap Sync now; that session will show whether the computer is connected and whether both sides are up to date.")
                .font(.footnote)
                .foregroundStyle(VaultPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vaultPanel()
    }

    private var thisIPadCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle("This iPad", icon: "ipad")
            if let localDeviceID {
                DeviceIDQRCode(deviceID: localDeviceID).frame(maxWidth: .infinity)
                Text(localDeviceID).font(.caption.monospaced()).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Preparing device identity").font(.caption.monospaced())
            }
            Text("Add this device ID to Syncthing on your computer as a remote device, then share the existing vault folder with this iPad.")
                .font(.footnote).foregroundStyle(VaultPalette.muted)
        }
        .vaultPanel()
    }

    private var peerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle("Existing Syncthing device", icon: "desktopcomputer")
            fieldLabel("Device ID")
            TextField("Paste or scan the device ID", text: $peerDeviceID, axis: .vertical)
                .font(.caption.monospaced())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(VaultPalette.parchment))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(VaultPalette.hairline, lineWidth: 1.5))
            VaultPillButton(title: "Scan device-ID QR code", systemImage: "qrcode.viewfinder",
                            style: .lilac) { isShowingScanner = true }
            fieldLabel("Device name")
            styledField($peerName, placeholder: "Desktop", mono: false, caps: true)
            fieldLabel("Optional TCP address")
            styledField($address, placeholder: "tcp://192.168.1.20:22000", mono: true, caps: false)
            Text("Leave the address empty to use Syncthing discovery and relays. Enter an explicit tcp:// address only when discovery is blocked on your network.")
                .font(.footnote).foregroundStyle(VaultPalette.muted)
        }
        .vaultPanel()
    }

    private var folderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle("Shared vault", icon: "folder.fill")
            fieldLabel("Syncthing folder ID")
            styledField($folderID, placeholder: "exactly as on the computer", mono: true, caps: false)
            fieldLabel("Display label")
            styledField($folderLabel, placeholder: "Notes", mono: false, caps: true)
            Text("On the computer, open this vault folder in Syncthing and copy its Folder ID. This is not the vault name or its file path. It must match exactly on both devices.")
                .font(.footnote).foregroundStyle(VaultPalette.muted)
        }
        .vaultPanel()
    }

    private func cardTitle(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(VaultType.body(.headline, weight: .bold))
            .foregroundStyle(VaultPalette.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(VaultPalette.muted)
    }

    private func styledField(_ text: Binding<String>, placeholder: String, mono: Bool, caps: Bool) -> some View {
        TextField(placeholder, text: text)
            .font(mono ? .subheadline.monospaced() : .subheadline)
            .textInputAutocapitalization(caps ? .words : .never)
            .autocorrectionDisabled()
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(VaultPalette.parchment))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(VaultPalette.hairline, lineWidth: 1.5))
    }

    private func save() {
        do {
            let normalized = try normalizeDeviceID(peerDeviceID)
            try onSave(SyncProfile(
                peerDeviceID: normalized,
                peerName: peerName,
                addresses: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? ["dynamic"] : [address],
                folderID: folderID,
                folderLabel: folderLabel
            ))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleScannedPayload(_ payload: String) {
        do {
            peerDeviceID = try DeviceIDPayloadParser(normalize: normalizeDeviceID).parse(payload)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isShowingScanner = false
    }
}
