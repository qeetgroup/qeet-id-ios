import Qeetrix
import SwiftUI

/// A full-screen QR scanner: the camera under the status bar, guidance, the target, the torch and the typed way in
/// underneath (screens 6, 7 and 12). Its owner decides what a code means.
struct ScannerScreen<Result: View>: View {
    let title: LocalizedStringKey
    let guidance: Text
    let typeInstead: Text
    let lock: AppLock
    let onPayload: @MainActor (String) -> Void
    let onTypeInstead: @MainActor () -> Void
    let onCancel: @MainActor () -> Void
    /// What was found, over the foot of the camera (Add this account?, Already added, Not a sign-in code).
    @ViewBuilder var result: () -> Result
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
        .overlay(alignment: .bottom) { result() }
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

extension ScannerScreen where Result == EmptyView {
    init(
        title: LocalizedStringKey, guidance: Text, typeInstead: Text, lock: AppLock, onPayload: @escaping @MainActor (String) -> Void,
        onTypeInstead: @escaping @MainActor () -> Void, onCancel: @escaping @MainActor () -> Void
    ) {
        self.init(
            title: title, guidance: guidance, typeInstead: typeInstead, lock: lock, onPayload: onPayload, onTypeInstead: onTypeInstead,
            onCancel: onCancel, result: { EmptyView() })
    }
}
