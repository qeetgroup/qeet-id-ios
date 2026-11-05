import Foundation

/// The one-time code that links this iPhone: ten Crockford Base32 characters, shown as "KM7QX-4TRWP" on the Qeet ID
/// setup page, and in its QR code as `qeetidauth://pair?code=KM7QX-4TRWP`.
enum PairingCode {
    /// Crockford's Base32: no I, L, O or U.
    private static let alphabet = Set("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    static let length = 10

    /// The code in `text` — the link a QR code holds, or the code typed — grouped as "ABCDE-FGHJK", or `nil` when it
    /// is neither. As the server reads it: case, spaces and hyphens don't matter, and O, I and L read as 0, 1 and 1.
    static func from(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme?.lowercased() == "qeetidauth" {
            return fromLink(url)
        }
        return normalized(trimmed)
    }

    /// The code in a `qeetidauth://pair?code=…` link.
    static func fromLink(_ url: URL) -> String? {
        guard url.scheme?.lowercased() == "qeetidauth", url.host?.lowercased() == "pair",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else { return nil }
        return normalized(code)
    }

    /// `text` as a code, grouped for reading, or `nil`.
    static func normalized(_ text: String) -> String? {
        var compact = ""
        for character in text.uppercased() {
            switch character {
            case " ", "-": continue
            case "O": compact.append("0")
            case "I", "L": compact.append("1")
            default:
                guard alphabet.contains(character) else { return nil }
                compact.append(character)
            }
        }
        guard compact.count == length else { return nil }
        return "\(compact.prefix(5))-\(compact.suffix(5))"
    }
}
