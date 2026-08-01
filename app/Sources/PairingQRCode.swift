import AVFoundation
import CoreImage
import SwiftUI
import UIKit

enum DeviceIDPayloadError: LocalizedError {
    case empty
    case invalid

    var errorDescription: String? {
        switch self {
        case .empty:
            return "The QR code did not contain a Syncthing device ID."
        case .invalid:
            return "That QR code is not a valid Syncthing device ID."
        }
    }
}

struct DeviceIDPayloadParser {
    let normalize: (String) throws -> String

    func parse(_ payload: String) throws -> String {
        let candidate = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else {
            throw DeviceIDPayloadError.empty
        }
        do {
            return try normalize(candidate)
        } catch {
            throw DeviceIDPayloadError.invalid
        }
    }
}

enum QRCodeRenderer {
    private static let context = CIContext()

    static func image(for payload: String) -> UIImage? {
        guard let data = payload.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator")
        else {
            return nil
        }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

struct DeviceIDQRCode: View {
    let deviceID: String

    var body: some View {
        if let image = QRCodeRenderer.image(for: deviceID) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("QR code for this iPad's Syncthing device ID")
        }
    }
}

struct QRCodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onCode: (String) -> Void
    @State private var cameraError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                QRCodeScannerView(
                    onCode: onCode,
                    onError: { cameraError = $0 }
                )
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 270, height: 270)
                    .accessibilityHidden(true)

                VStack {
                    Spacer()
                    if let cameraError {
                        Label(cameraError, systemImage: "camera.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                            .padding()
                    } else {
                        Text("Point the camera at the device-ID QR code shown by Syncthing on your computer.")
                            .font(.footnote.weight(.medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                            .padding()
                    }
                }
            }
            .navigationTitle("Scan computer ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        QRCodeScannerViewController(onCode: onCode, onError: onError)
    }

    func updateUIViewController(
        _ uiViewController: QRCodeScannerViewController,
        context: Context
    ) {}
}

private final class QRCodeScannerViewController: UIViewController,
    AVCaptureMetadataOutputObjectsDelegate
{
    private let captureSession = AVCaptureSession()
    private let captureQueue = DispatchQueue(
        label: "com.mvmc4.obsidian-sync-ios.qr-capture",
        qos: .userInitiated
    )
    private let onCode: (String) -> Void
    private let onError: (String) -> Void
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasDeliveredCode = false

    init(onCode: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onCode = onCode
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestCameraAndConfigure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    private func requestCameraAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.configureCapture()
                    } else {
                        self.onError("Camera access is required to scan a device ID. You can still paste it manually.")
                    }
                }
            }
        case .denied, .restricted:
            onError("Camera access is unavailable. Allow it in Settings or paste the device ID manually.")
        @unknown default:
            onError("The camera is unavailable. Paste the device ID manually.")
        }
    }

    private func configureCapture() {
        guard let camera = AVCaptureDevice.default(for: .video) else {
            onError("No camera is available. Paste the device ID manually.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard captureSession.canAddInput(input) else {
                onError("The camera could not be opened. Paste the device ID manually.")
                return
            }
            captureSession.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard captureSession.canAddOutput(output) else {
                onError("QR scanning is unavailable. Paste the device ID manually.")
                return
            }
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let preview = AVCaptureVideoPreviewLayer(session: captureSession)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.insertSublayer(preview, at: 0)
            previewLayer = preview

            captureQueue.async { [captureSession] in
                captureSession.startRunning()
            }
        } catch {
            onError("The camera could not be opened. Paste the device ID manually.")
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasDeliveredCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue
        else {
            return
        }
        hasDeliveredCode = true
        onCode(value)
    }
}
