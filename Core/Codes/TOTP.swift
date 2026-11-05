import CryptoKit
import Foundation

/// The settings a site's codes are made with, apart from the secret.
struct OTPParameters: Codable, Hashable, Sendable {
    var algorithm: OTPAlgorithm = .sha1
    /// 6 or 8.
    var digits: Int = 6
    /// Seconds each code lasts: 30, or 60 for some sites.
    var period: Int = 30

    static let supportedDigits = [6, 8]
    static let supportedPeriods = [30, 60]
}

/// RFC 6238 time-based one-time passwords: an RFC 4226 HOTP of the number of periods since the Unix epoch.
enum TOTP {
    /// The code for `date`.
    static func code(key: SymmetricKey, at date: Date, parameters: OTPParameters) -> String {
        hotp(key: key, counter: counter(at: date, period: parameters.period), digits: parameters.digits, algorithm: parameters.algorithm)
    }

    /// The time step `date` falls in.
    static func counter(at date: Date, period: Int) -> UInt64 {
        let seconds = max(0, date.timeIntervalSince1970)
        return UInt64(seconds) / UInt64(max(1, period))
    }

    /// When the code shown at `date` became valid, and when the next one replaces it.
    static func validity(at date: Date, period: Int) -> ClosedRange<Date> {
        let step = counter(at: date, period: period)
        let start = Date(timeIntervalSince1970: TimeInterval(step * UInt64(max(1, period))))
        return start...start.addingTimeInterval(TimeInterval(max(1, period)))
    }

    /// RFC 4226 §5.3: HMAC the counter, truncate dynamically, keep the last `digits` digits.
    static func hotp(key: SymmetricKey, counter: UInt64, digits: Int, algorithm: OTPAlgorithm) -> String {
        var bigEndian = counter.bigEndian
        let message = withUnsafeBytes(of: &bigEndian) { Data($0) }
        let mac = Array(algorithm.authenticationCode(for: message, key: key))
        let offset = Int(mac[mac.count - 1] & 0x0F)
        let binary =
            (UInt32(mac[offset] & 0x7F) << 24) | (UInt32(mac[offset + 1]) << 16) | (UInt32(mac[offset + 2]) << 8)
            | UInt32(mac[offset + 3])
        var modulus: UInt32 = 1
        for _ in 0..<digits { modulus *= 10 }
        let value = binary % modulus
        let text = String(value)
        return String(repeating: "0", count: max(0, digits - text.count)) + text
    }
}
