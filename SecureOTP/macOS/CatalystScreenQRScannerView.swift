import SwiftUI

#if targetEnvironment(macCatalyst)
import UIKit
import Vision

struct CatalystScreenQRScannerView: View {
    var onCodeScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var capturedImage: UIImage?
    @State private var detectedCode: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Instructions
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.dashed.and.paperclip")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("Display the QR code on your screen")
                        .font(.headline)

                    Text("Click the button below to capture your screen and detect the QR code automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)

                // Captured image preview
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(detectedCode != nil ? Color.green : Color.gray, lineWidth: 2)
                        )
                }

                // Status
                if let code = detectedCode {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("QR Code detected!")
                            .foregroundStyle(.green)
                    }
                    .font(.headline)
                } else if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.orange)
                    }
                    .font(.subheadline)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: captureScreen) {
                        HStack {
                            if isScanning {
                                ProgressView()
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "camera.viewfinder")
                            }
                            Text(isScanning ? "Scanning..." : "Capture Screen")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isScanning)

                    if detectedCode != nil {
                        Button(action: {
                            if let code = detectedCode {
                                onCodeScanned(code)
                                dismiss()
                            }
                        }) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Use This QR Code")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
            }
            .padding(24)
            .navigationTitle("Scan QR Code from Screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func captureScreen() {
        isScanning = true
        errorMessage = nil
        detectedCode = nil

        // Take screenshot using UIScreen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                errorMessage = "Could not access screen"
                isScanning = false
                return
            }

            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let screenshot = renderer.image { context in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }

            capturedImage = screenshot
            detectQRCode(in: screenshot)
        }
    }

    private func detectQRCode(in image: UIImage) {
        guard let cgImage = image.cgImage else {
            errorMessage = "Failed to process image"
            isScanning = false
            return
        }

        let request = VNDetectBarcodesRequest { request, error in
            DispatchQueue.main.async {
                if let results = request.results as? [VNBarcodeObservation] {
                    for result in results {
                        if result.symbology == .qr, let payload = result.payloadStringValue {
                            if payload.starts(with: "otpauth://") {
                                detectedCode = payload
                                isScanning = false
                                return
                            }
                        }
                    }
                }
                errorMessage = "No OTP QR code found. Make sure the QR code is visible on screen."
                isScanning = false
            }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            DispatchQueue.main.async {
                errorMessage = "QR detection failed: \(error.localizedDescription)"
                isScanning = false
            }
        }
    }
}
#endif
