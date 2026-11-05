import Qeetrix
import SwiftUI

/// Sign-in approvals, the app lock, AutoFill and About.
struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: QeetrixSpace.gapLg) {
                QeetrixCard("Security") {
                    QeetrixText("Face ID lock and hidden codes.", tone: .subtle)
                }
            }
            .padding(QeetrixSpace.insetLg)
        }
        .background(QeetrixColor.surfaceCanvas)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .qeetrixNavigationBar(background: .canvas, title: .qeetrix)
    }
}
