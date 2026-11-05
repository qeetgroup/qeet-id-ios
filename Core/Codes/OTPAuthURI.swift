import Foundation

/// Reads `otpauth://totp/…` links, the format of the QR codes sites show when 2-step verification is turned on
/// (Google's Key Uri Format).
///
/// `otpauth://totp/GitHub:brightleaf-foods?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA1&digits=6&period=30`
enum OTPAuthURI {
    static func parse(_ text: String) throws(SetupKeyError) -> AccountDraft {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Some sites leave spaces in the label unencoded.
        let encoded = trimmed.replacingOccurrences(of: " ", with: "%20")
        guard let components = URLComponents(string: encoded), let scheme = components.scheme?.lowercased() else {
            throw .notACodeQR
        }
        if scheme == "otpauth-migration" { throw .transferQR }
        guard scheme == "otpauth" else { throw .notACodeQR }
        switch components.host?.lowercased() {
        case "totp": break
        case "hotp": throw .counterBased
        default: throw .notACodeQR
        }

        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            // The first of a repeated parameter wins.
            let key = item.name.lowercased()
            if query[key] == nil, let value = item.value { query[key] = value }
        }

        guard let secretText = query["secret"], !secretText.isEmpty else { throw .keyMissing }
        let secret = try SetupKey.decode(secretText)

        // The label: "Issuer:account", "Issuer: account" or just "account", percent-decoded.
        let label = String(components.path.drop(while: { $0 == "/" }))
        var labelIssuer: String?
        var name = label
        if let colon = label.firstIndex(of: ":") {
            labelIssuer = String(label[..<colon]).trimmingCharacters(in: .whitespaces)
            name = String(label[label.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        let issuer = (query["issuer"]?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? labelIssuer ?? ""

        var parameters = OTPParameters()
        if let algorithm = query["algorithm"] {
            guard let parsed = OTPAlgorithm(rawValue: algorithm.uppercased().replacingOccurrences(of: "-", with: "")) else {
                throw .unsupportedSettings
            }
            parameters.algorithm = parsed
        }
        if let digits = query["digits"] {
            guard let parsed = Int(digits), OTPParameters.supportedDigits.contains(parsed) else { throw .unsupportedSettings }
            parameters.digits = parsed
        }
        if let period = query["period"] {
            guard let parsed = Int(period), (1...300).contains(parsed) else { throw .unsupportedSettings }
            parameters.period = parsed
        }

        if issuer.isEmpty && name.isEmpty { throw .notACodeQR }
        return AccountDraft(
            issuer: issuer.isEmpty ? name : issuer, name: issuer.isEmpty ? "" : name, secret: secret, parameters: parameters)
    }
}
