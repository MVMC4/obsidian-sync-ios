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
        _address = State(
            initialValue: existingProfile?.addresses.first == "dynamic"
                ? ""
                : existingProfile?.addresses.first ?? ""
        )
        _folderID = State(initialValue: existingProfile?.folderID ?? "")
        _folderLabel = State(initialValue: existingProfile?.folderLabel ?? "Notes")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("This iPad") {
                    if let localDeviceID {
                        DeviceIDQRCode(deviceID: localDeviceID)
                            .frame(maxWidth: .infinity)
                        Text(localDeviceID)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    } else {
                        Text("Preparing device identity…")
                            .font(.caption.monospaced())
                    }
                    Text("Add this device ID to Syncthing on your computer as a remote device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("On the computer, share the existing vault folder with this iPad. Keep the computer awake and Syncthing running during the first session.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Existing Syncthing device") {
                    TextField("Device ID", text: $peerDeviceID, axis: .vertical)
                        .font(.caption.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Scan device-ID QR code", systemImage: "qrcode.viewfinder") {
                        isShowingScanner = true
                    }
                    TextField("Device name", text: $peerName)
                    TextField("Optional TCP address", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Leave the address empty to use Syncthing discovery and relays, or enter something like tcp://192.168.1.20:22000.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Shared vault") {
                    TextField("Syncthing folder ID", text: $folderID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Display label", text: $folderLabel)
                    Text("The folder ID must exactly match the folder ID configured for the vault on your computer.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(existingProfile == nil ? "Pair a device" : "Sync settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                QRCodeScannerSheet { payload in
                    handleScannedPayload(payload)
                }
            }
        }
    }

    private func save() {
        do {
            let normalizedPeerDeviceID = try normalizeDeviceID(peerDeviceID)
            try onSave(
                SyncProfile(
                    peerDeviceID: normalizedPeerDeviceID,
                    peerName: peerName,
                    addresses: address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? ["dynamic"]
                        : [address],
                    folderID: folderID,
                    folderLabel: folderLabel
                )
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleScannedPayload(_ payload: String) {
        do {
            peerDeviceID = try DeviceIDPayloadParser(
                normalize: normalizeDeviceID
            ).parse(payload)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isShowingScanner = false
    }
}
