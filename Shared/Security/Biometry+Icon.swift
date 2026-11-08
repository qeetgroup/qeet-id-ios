import Qeetrix

extension Biometry {
    /// The icon the mockups put on Use Face ID and Unlock: scan-face for Face ID (and Optic ID), the fingerprint for
    /// Touch ID; none for the passcode alone.
    var icon: QeetrixIconName? {
        switch self {
        case .faceID, .opticID: .scanFace
        case .touchID: .fingerprintPattern
        case .passcode: nil
        }
    }
}
