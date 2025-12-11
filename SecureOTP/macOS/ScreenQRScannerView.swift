import SwiftUI
import ScreenCaptureKit
import Vision

#if os(macOS)
import AppKit

// MARK: - QR Scanner Window Controller (Non-singleton)
class QRScannerWindowController: NSObject, NSWindowDelegate {
    private var scannerWindow: NSWindow?
    private var imageView: NSImageView?
    private var statusLabel: NSTextField?
    private var scanButton: NSButton?
    private weak var callbackTarget: AnyObject?
    private var onCodeDetected: ((String) -> Void)?

    func showScanner(onDetected: @escaping (String) -> Void) {
        // Close existing window if any
        closeWindow()

        onCodeDetected = onDetected
        setupWindow()
    }

    private func setupWindow() {
        let width: CGFloat = 300
        let height: CGFloat = 340

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "QR Scanner"
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces]
        window.delegate = self

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        contentView.wantsLayer = true

        // Image view for preview
        let imgView = NSImageView(frame: NSRect(x: 15, y: 80, width: width - 30, height: height - 95))
        imgView.imageScaling = .scaleProportionallyUpOrDown
        imgView.wantsLayer = true
        imgView.layer?.cornerRadius = 12
        imgView.layer?.masksToBounds = true
        imgView.layer?.borderColor = NSColor.systemBlue.cgColor
        imgView.layer?.borderWidth = 3
        imgView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.05).cgColor
        contentView.addSubview(imgView)
        imageView = imgView

        // Status label
        let label = NSTextField(labelWithString: "Position this window over a QR code")
        label.frame = NSRect(x: 15, y: 50, width: width - 30, height: 20)
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        contentView.addSubview(label)
        statusLabel = label

        // Scan button
        let button = NSButton(frame: NSRect(x: 15, y: 10, width: width - 30, height: 32))
        button.title = "Scan"
        button.bezelStyle = .push
        button.isBordered = true
        button.target = self
        button.action = #selector(scanButtonClicked)
        contentView.addSubview(button)
        scanButton = button

        window.contentView = contentView

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            window.setFrameOrigin(NSPoint(
                x: screenFrame.midX - width / 2,
                y: screenFrame.midY - height / 2
            ))
        }

        scannerWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func scanButtonClicked() {
        print("DEBUG: Scan button clicked")
        guard let window = scannerWindow else {
            print("DEBUG: No scanner window")
            return
        }

        statusLabel?.stringValue = "Scanning..."
        scanButton?.isEnabled = false

        let frame = window.frame
        let windowID = window.windowNumber
        print("DEBUG: Window frame: \(frame), windowID: \(windowID)")

        Task { [weak self] in
            guard let self = self else {
                print("DEBUG: Self is nil")
                return
            }

            do {
                print("DEBUG: Getting shareable content...")
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                print("DEBUG: Got content, displays: \(content.displays.count), windows: \(content.windows.count)")
                guard let display = content.displays.first else {
                    await MainActor.run { [weak self] in
                        self?.showError("No display found")
                    }
                    return
                }

                let excludeWindows = content.windows.filter { $0.windowID == CGWindowID(windowID) }

                let captureRect = CGRect(
                    x: frame.origin.x,
                    y: CGFloat(display.height) - frame.origin.y - frame.height,
                    width: frame.width,
                    height: frame.height
                )

                let config = SCStreamConfiguration()
                config.sourceRect = captureRect
                config.width = Int(frame.width * 2)
                config.height = Int(frame.height * 2)
                config.showsCursor = false
                config.capturesAudio = false

                let filter = SCContentFilter(display: display, excludingWindows: excludeWindows)
                print("DEBUG: Capturing image...")
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                print("DEBUG: Captured image: \(cgImage.width)x\(cgImage.height)")

                // Update preview
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    self.imageView?.image = nsImage
                }

                // Detect QR
                print("DEBUG: Detecting QR codes...")
                let request = VNDetectBarcodesRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage)
                try handler.perform([request])

                print("DEBUG: Results count: \(request.results?.count ?? 0)")
                var foundQR = false
                if let results = request.results {
                    for barcode in results {
                        print("DEBUG: Found barcode: \(barcode.symbology), payload: \(barcode.payloadStringValue ?? "nil")")
                        if barcode.symbology == .qr,
                           let payload = barcode.payloadStringValue,
                           payload.hasPrefix("otpauth://") {
                            foundQR = true
                            print("DEBUG: Found OTP QR code!")
                            await MainActor.run { [weak self] in
                                guard let self = self else { return }
                                let callback = self.onCodeDetected
                                self.closeWindow()
                                callback?(payload)
                            }
                            return
                        }
                    }
                }

                if !foundQR {
                    print("DEBUG: No QR code found")
                    await MainActor.run { [weak self] in
                        self?.showError("No QR code found. Try again.")
                    }
                }

            } catch {
                print("DEBUG: Error: \(error)")
                await MainActor.run { [weak self] in
                    self?.showError("Capture failed. Check screen recording permission.")
                }
            }
        }
    }

    private func showError(_ message: String) {
        statusLabel?.stringValue = message
        statusLabel?.textColor = .systemOrange
        scanButton?.isEnabled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self, self.scannerWindow != nil else { return }
            self.statusLabel?.stringValue = "Position this window over a QR code"
            self.statusLabel?.textColor = .secondaryLabelColor
        }
    }

    private func closeWindow() {
        // Clear callback first
        onCodeDetected = nil

        // Clear delegate before closing
        scannerWindow?.delegate = nil
        scannerWindow?.close()
        scannerWindow = nil
        imageView = nil
        statusLabel = nil
        scanButton = nil
    }

    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        // Clear delegate immediately
        if let window = notification.object as? NSWindow {
            window.delegate = nil
        }

        onCodeDetected = nil
        scannerWindow = nil
        imageView = nil
        statusLabel = nil
        scanButton = nil
    }
}

// MARK: - Global accessor (creates new instance each time)
enum MagnifierScannerController {
    private static var currentController: QRScannerWindowController?

    static func startScanning(onDetected: @escaping (String) -> Void) {
        // Create new controller for each scan session
        let controller = QRScannerWindowController()
        currentController = controller
        controller.showScanner(onDetected: onDetected)
    }
}

#endif
