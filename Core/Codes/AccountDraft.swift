import Foundation

/// An account about to be added: what a QR code or a typed setup key says, before it is stored.
struct AccountDraft: Sendable {
    var issuer: String
    var name: String
    /// The decoded key. Never shown, logged or kept in a view's state.
    var secret: Data
    var parameters: OTPParameters

    /// Below this, a key is too weak to trust: 80 bits, the shortest that sites hand out (16 Base32 characters).
    static let minimumSecretLength = 10
}

/// Why a QR code or a setup key can't become an account. Each says what to do.
enum SetupKeyError: Error, Equatable, Sendable {
    /// A QR code that isn't an `otpauth://` link.
    case notACodeQR
    /// An `otpauth://hotp/` link: counter-based codes, which this app doesn't make.
    case counterBased
    /// An `otpauth-migration://` export from another authenticator.
    case transferQR
    /// No key at all.
    case keyMissing
    /// A key with characters Base32 doesn't have.
    case keyInvalid
    /// A key under 80 bits.
    case keyTooShort
    /// Digits or a period the app can't show.
    case unsupportedSettings

    var message: String {
        switch self {
        case .notACodeQR:
            String(localized: "This QR code isn't for sign-in codes. Scan the code on the site's 2-step verification page.")
        case .counterBased:
            String(localized: "This account uses counter-based codes, which Qeet ID doesn't make. Ask the site for time-based codes.")
        case .transferQR:
            String(localized: "This QR code moves accounts out of another app. Add each account from its own website instead.")
        case .keyMissing:
            String(localized: "Enter the setup key from the site.")
        case .keyInvalid:
            String(localized: "Keys use only A–Z and 2–7. A 0, 1 or 8 is usually the letter O, I or B.")
        case .keyTooShort:
            String(localized: "Setup keys have at least 16 characters.")
        case .unsupportedSettings:
            String(localized: "This account's codes use settings Qeet ID doesn't support.")
        }
    }
}

/// Reads setup keys as people type them.
enum SetupKey {
    /// The key's bytes, or why it can't be one.
    static func decode(_ text: String) throws(SetupKeyError) -> Data {
        let compact = text.filter { !$0.isWhitespace && $0 != "-" }
        guard !compact.isEmpty else { throw .keyMissing }
        guard let secret = Base32.decode(compact) else { throw .keyInvalid }
        guard secret.count >= AccountDraft.minimumSecretLength else { throw .keyTooShort }
        return secret
    }
}
