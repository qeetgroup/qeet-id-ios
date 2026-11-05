@preconcurrency import AVFoundation
import Observation
import Qeetrix
import SwiftUI

/// The back camera, reading QR codes. Qeetrix draws the scanner around it; this owns AVFoundation, the camera
/// permission and the torch, and hands each code it reads to `onPayload`.
@MainActor
@Observable
final class QRCamera: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    /// What the scanner shows.
    private(set) var state: QeetrixQRScannerState = .scanning
    private(set) var hasTorch = false
    var isTorchOn = false {
        didSet { applyTorch() }
    }

    /// Called on the main actor with each code read, at most once a second for the same code.
    @ObservationIgnored var onPayload: (@MainActor (String) -> Void)?

    /// AVFoundation's session. Starting and stopping it blocks, so they run on `queue`; AVCaptureSession is safe to
    /// start and stop from another thread, which is why it is exempt from isolation here.
    @ObservationIgnored nonisolated(unsafe) let session = AVCaptureSession()
    @ObservationIgnored private let queue = DispatchQueue(label: "com.qeetgroup.qeetid.camera")
    @ObservationIgnored private var device: AVCaptureDevice?
    @ObservationIgnored private var isConfigured = false
    @ObservationIgnored private var lastPayload: (text: String, at: Date)?

    /// Reads the permission and, when allowed, configures and starts the camera.
    func prepare() {
        #if DEBUG
            if UITestSupport.simulatedScan != nil {
                state = .scanning
                return
            }
        #endif
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            state = .notDetermined
        default:
            state = .denied
        }
    }

    /// Asks iOS for the camera, after the primer's Continue.
    func requestAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted { configureAndStart() } else { state = .denied }
    }

    func stop() {
        isTorchOn = false
        let session = self.session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    func resume() {
        guard isConfigured else { return }
        let session = self.session
        queue.async { if !session.isRunning { session.startRunning() } }
    }

    private func configureAndStart() {
        guard !isConfigured else { return resume() }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input)
        else {
            state = .unavailable
            return
        }
        session.beginConfiguration()
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            state = .unavailable
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = output.availableMetadataObjectTypes.contains(.qr) ? [.qr] : []
        session.commitConfiguration()
        self.device = device
        hasTorch = device.hasTorch
        isConfigured = true
        state = .scanning
        resume()
    }

    private func applyTorch() {
        guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = isTorchOn ? .on : .off
        device.unlockForConfiguration()
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection
    ) {
        guard let text = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        // The delegate queue is the main queue (configureAndStart).
        MainActor.assumeIsolated { deliver(text) }
    }

    func deliver(_ text: String) {
        let now = Date()
        if let last = lastPayload, last.text == text, now.timeIntervalSince(last.at) < 1 { return }
        lastPayload = (text, now)
        onPayload?(text)
    }
}

/// The camera's picture, filling its space.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
