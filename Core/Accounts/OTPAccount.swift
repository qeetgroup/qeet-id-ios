import Foundation

/// An account the app makes codes for, without its secret: what can be listed, shown and synced to AutoFill.
struct OTPAccount: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    /// The site or app: "GitHub".
    var issuer: String
    /// The account at that site: "brightleaf-foods". May be empty.
    var name: String
    var parameters: OTPParameters
    let createdAt: Date
    /// Sites the person chose this account for in AutoFill, so AutoFill can offer it there first. Never guessed.
    var websites: [String] = []

    /// The letter on the account's tile: the issuer's first letter or digit.
    var monogram: String {
        let source = issuer.isEmpty ? name : issuer
        guard let first = source.first(where: { $0.isLetter || $0.isNumber }) else { return "#" }
        return String(first).uppercased()
    }

    /// What VoiceOver reads before a code: "GitHub, brightleaf-foods".
    var spokenName: String {
        name.isEmpty ? issuer : "\(issuer), \(name)"
    }
}
