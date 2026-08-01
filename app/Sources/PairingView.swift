import SwiftUI

struct PairingView: View {
    @Environment(\.dismiss) private var dismiss

    let existingProfile: SyncProfile?
    let localDeviceID: String?
    let onSave: (SyncProfile) throws -> Void

    @State private var peerDeviceID: String
    @State private var peerName: String
    @State private var address: String
    @State private var folderID: String
    @State private var folderLabel: String
    @State private var errorMessage: String?

    init(
        existingProfile: SyncProfile?,
        localDeviceID: String?,
        onSave: @escaping (SyncProfile) throws -> Void
    ) {
        self.existingProfile = existingProfile
        self.localDeviceID = localDeviceID
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
                    Text(localDeviceID ?? "Preparing device identity…")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
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
        }
    }

    private func save() {
        do {
            try onSave(
                SyncProfile(
                    peerDeviceID: peerDeviceID,
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
}
