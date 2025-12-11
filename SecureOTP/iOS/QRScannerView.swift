import SwiftUI
import AVFoundation

#if os(iOS)
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onScan: (String) -> Void

    @State private var isScanning = true
    @State private var scannedCode: String?
    @State private var showPermissionDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                if showPermissionDenied {
                    permissionDeniedView
                } else {
                    QRScannerRepresentable(
                        isScanning: $isScanning,
                        scannedCode: $scannedCode
                    )
                    .ignoresSafeArea()

                    scannerOverlay
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: scannedCode) { _, newValue in
                if let code = newValue {
                    onScan(code)
                    dismiss()
                }
            }
            .onAppear {
                checkCameraPermission()
            }
        }
    }

    private var scannerOverlay: some View {
        VStack {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 250, height: 250)

                // Corner accents
                VStack {
                    HStack {
                        CornerShape()
                            .stroke(Color.blue, lineWidth: 4)
                            .frame(width: 40, height: 40)
                        Spacer()
                        CornerShape()
                            .stroke(Color.blue, lineWidth: 4)
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(90))
                    }
                    Spacer()
                    HStack {
                        CornerShape()
                            .stroke(Color.blue, lineWidth: 4)
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                        Spacer()
                        CornerShape()
                            .stroke(Color.blue, lineWidth: 4)
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(180))
                    }
                }
                .frame(width: 250, height: 250)
            }

            Spacer()

            Text("Position QR code within the frame")
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, 50)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.bold)

            Text("Please allow camera access in Settings to scan QR codes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showPermissionDenied = false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    showPermissionDenied = !granted
                }
            }
        default:
            showPermissionDenied = true
        }
    }
}

struct CornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

struct QRScannerRepresentable: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    @Binding var scannedCode: String?

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QRScannerDelegate {
        let parent: QRScannerRepresentable

        init(_ parent: QRScannerRepresentable) {
            self.parent = parent
        }

        func didScanCode(_ code: String) {
            parent.isScanning = false
            parent.scannedCode = code
        }
    }
}

protocol QRScannerDelegate: AnyObject {
    func didScanCode(_ code: String)
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRScannerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(videoInput) else {
            return
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        self.previewLayer = previewLayer
        self.captureSession = session

        startScanning()
    }

    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        stopScanning()
        delegate?.didScanCode(stringValue)
    }
}
#endif
