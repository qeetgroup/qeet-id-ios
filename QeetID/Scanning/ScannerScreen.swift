import Qeetrix
import SwiftUI

/// A full-screen QR scanner: the camera under the status bar, guidance, the target, the torch and the typed way in
/// underneath (screens 6, 7 and 12). Its owner decides what a code means.
struct ScannerScreen: View {
    let title: LocalizedStringKey
    let guidance: Text
    let typeInstead: Text
    let lock: AppLock
    let onPayload: @MainActor (String) -> Void
    let onTypeInstead: @MainActor () -> Void
    let onCancel: @MainActor () -> Void
    @State private var camera = QRCamera()

    var body: some View {
        QeetrixQRScanner(
            state: camera.state,
            isTorchOn: camera.hasTorch ? Binding(get: { camera.isTorchOn }, set: { camera.isTorchOn = $0 }) : nil,
            messages: QeetrixQRScannerMessages(guidance: guidance, typeKey: typeInstead),
            onContinue: { requestAccess() },
            onTypeKey: { onTypeInstead() }
        ) {
            CameraPreview(session: camera.session)
        }
        .background(camera.state == .scanning ? Color.black : Color.clear)
        .background(QeetrixColor.surfaceCanvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(camera.state == .scanning ? Color.black : Color.clear, for: .navigationBar)
        .toolbarBackground(camera.state == .scanning ? .visible : .automatic, for: .navigationBar)
        .toolbarColorScheme(camera.state == .scanning ? .dark : nil, for: .navigationBar)
        .qeetrixNavigationBar(title: .qeetrix)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
                    .accessibilityIdentifier("scanner.cancel")
            }
        }
        .onAppear {
            camera.onPayload = onPayload
            camera.prepare()
        }
        .onDisappear { camera.stop() }
        .task { await simulateScanForUITests() }
    }

    private func requestAccess() {
        Task {
            lock.beginSystemPrompt()
            await camera.requestAccess()
            lock.endSystemPrompt()
        }
    }

    private func simulateScanForUITests() async {
        #if DEBUG
            guard let payload = UITestSupport.simulatedScan else { return }
            try? await Task.sleep(for: .milliseconds(600))
            camera.deliver(payload)
        #endif
    }
}
