import CryptoKit
import Foundation

/// The HMAC a site's codes use. SHA-1 is RFC 6238's default and what almost every site uses.
enum OTPAlgorithm: String, Codable, CaseIterable, Sendable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"

    /// As people read it: "SHA-1".
    var displayName: String {
        switch self {
        case .sha1: "SHA-1"
        case .sha256: "SHA-256"
        case .sha512: "SHA-512"
        }
    }

    /// The HMAC of `message` under `key`.
    func authenticationCode(for message: Data, key: SymmetricKey) -> Data {
        switch self {
        case .sha1: Data(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256: Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512: Data(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }
    }
}
