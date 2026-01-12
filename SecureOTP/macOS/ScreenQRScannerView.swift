import SwiftUI
import ScreenCaptureKit
import Vision

#if os(macOS)
import AppKit

// MARK: - Screen Selection Overlay Window
class ScreenSelectionOverlayWindow: NSWindow {
    var onAreaSelected: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var selectionView: ScreenSelectionView?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = ScreenSelectionView(frame: screen.frame)
        view.onAreaSelected = { [weak self] rect in
            self?.onAreaSelected?(rect)
        }
        view.onCancel = { [weak self] in
            self?.onCancel?()
        }
        selectionView = view
        contentView = view
    }
}

// MARK: - Screen Selection View
class ScreenSelectionView: NSView {
    var onAreaSelected: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    private var instructionLabel: NSTextField?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true

        // Add instruction label
        let label = NSTextField(labelWithString: "드래그하여 QR 코드 영역을 선택하세요 (ESC로 취소)")
        label.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        label.isBordered = false
        label.alignment = .center
        label.sizeToFit()

        let labelWidth = label.frame.width + 40
        let labelHeight: CGFloat = 44
        label.frame = NSRect(
            x: (bounds.width - labelWidth) / 2,
            y: bounds.height - 100,
            width: labelWidth,
            height: labelHeight
        )
        label.wantsLayer = true
        label.layer?.cornerRadius = 8
        label.layer?.masksToBounds = true

        addSubview(label)
        instructionLabel = label
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Semi-transparent overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        // Draw selection rectangle if exists
        if let rect = currentRect {
            // Clear the selection area
            NSColor.clear.setFill()
            rect.fill(using: .clear)

            // Draw border
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 3
            path.stroke()

            // Draw corner handles
            let handleSize: CGFloat = 10
            NSColor.white.setFill()

            let corners = [
                NSPoint(x: rect.minX, y: rect.minY),
                NSPoint(x: rect.maxX, y: rect.minY),
                NSPoint(x: rect.minX, y: rect.maxY),
                NSPoint(x: rect.maxX, y: rect.maxY)
            ]

            for corner in corners {
                let handleRect = NSRect(
                    x: corner.x - handleSize/2,
                    y: corner.y - handleSize/2,
                    width: handleSize,
                    height: handleSize
                )
                NSBezierPath(ovalIn: handleRect).fill()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)

        currentRect = NSRect(x: x, y: y, width: width, height: height)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let rect = currentRect, rect.width > 20, rect.height > 20 else {
            startPoint = nil
            currentRect = nil
            needsDisplay = true
            return
        }

        // Convert to screen coordinates
        guard let window = window else { return }
        let screenRect = window.convertToScreen(rect)

        onAreaSelected?(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onCancel?()
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        return true
    }
}

// MARK: - QR Scanner Controller
class ScreenQRScannerController: NSObject {
    private var overlayWindows: [ScreenSelectionOverlayWindow] = []
    private var onCodeDetected: ((String) -> Void)?

    func startScanning(onDetected: @escaping (String) -> Void) {
        onCodeDetected = onDetected
        showOverlay()
    }

    private func showOverlay() {
        // Close any existing overlays
        closeOverlays()

        // Create overlay for each screen
        for screen in NSScreen.screens {
            let overlay = ScreenSelectionOverlayWindow(screen: screen)
            overlay.onAreaSelected = { [weak self] rect in
                self?.captureAndScan(rect: rect)
            }
            overlay.onCancel = { [weak self] in
                self?.closeOverlays()
            }
            overlay.makeKeyAndOrderFront(nil)
            overlay.makeFirstResponder(overlay.contentView)
            overlayWindows.append(overlay)
        }
    }

    private func closeOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
    }

    private func captureAndScan(rect: CGRect) {
        // Close overlays first
        closeOverlays()

        // Small delay to ensure overlay is gone before capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.performCapture(rect: rect)
        }
    }

    private func performCapture(rect: CGRect) {
        Task { [weak self] in
            guard let self = self else { return }

            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    await self.showError("디스플레이를 찾을 수 없습니다")
                    return
                }

                // Convert rect to display coordinates (flip Y)
                let captureRect = CGRect(
                    x: rect.origin.x,
                    y: CGFloat(display.height) - rect.origin.y - rect.height,
                    width: rect.width,
                    height: rect.height
                )

                let config = SCStreamConfiguration()
                config.sourceRect = captureRect
                config.width = Int(rect.width * 2)
                config.height = Int(rect.height * 2)
                config.showsCursor = false
                config.capturesAudio = false

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

                // Detect QR code
                let request = VNDetectBarcodesRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage)
                try handler.perform([request])

                if let results = request.results {
                    for barcode in results {
                        if barcode.symbology == .qr,
                           let payload = barcode.payloadStringValue,
                           payload.hasPrefix("otpauth://") {
                            await MainActor.run { [weak self] in
                                self?.onCodeDetected?(payload)
                            }
                            return
                        }
                    }
                }

                await self.showError("QR 코드를 찾을 수 없습니다. 다시 시도해주세요.")

            } catch {
                await self.showError("캡처 실패. 화면 녹화 권한을 확인해주세요.")
            }
        }
    }

    @MainActor
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "QR 스캔 실패"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "다시 시도")
        alert.addButton(withTitle: "취소")

        if alert.runModal() == .alertFirstButtonReturn {
            showOverlay()
        }
    }
}

// MARK: - Global Scanner Controller
enum MagnifierScannerController {
    private static var currentController: ScreenQRScannerController?

    static func startScanning(onDetected: @escaping (String) -> Void) {
        stopScanning()

        let controller = ScreenQRScannerController()
        currentController = controller
        controller.startScanning { payload in
            currentController = nil
            onDetected(payload)
        }
    }

    static func stopScanning() {
        currentController = nil
    }
}

#endif
