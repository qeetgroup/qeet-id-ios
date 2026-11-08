import Qeetrix
import SwiftUI

/// Screens 1 to 3: Welcome, then the lock, then notifications. Comfortable density throughout (design rules §17).
struct OnboardingFlow: View {
    let model: AppModel
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(biometry: model.lock.biometry) { path.append(.lock) }
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .lock:
                        LockSetupView(lock: model.lock) { path.append(.notifications) }
                    case .notifications:
                        NotificationsPrimerView(lock: model.lock) { model.completeOnboarding() }
                    }
                }
        }
        .qeetrixDensity(.comfortable)
    }
}

enum OnboardingStep: Hashable {
    case lock
    case notifications
}
