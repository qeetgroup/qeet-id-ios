import CryptoKit
import Foundation
import Testing

@testable import QeetID

/// RFC 6238 Appendix B and RFC 4226 Appendix D.
struct TOTPTests {
    static let sha1Key = SymmetricKey(data: Data("12345678901234567890".utf8))
    static let sha256Key = SymmetricKey(data: Data("12345678901234567890123456789012".utf8))
    static let sha512Key = SymmetricKey(data: Data("1234567890123456789012345678901234567890123456789012345678901234".utf8))

    static let vectors: [(time: TimeInterval, sha1: String, sha256: String, sha512: String)] = [
        (59, "94287082", "46119246", "90693936"),
        (1_111_111_109, "07081804", "68084774", "25091201"),
        (1_111_111_111, "14050471", "67062674", "99943326"),
        (1_234_567_890, "89005924", "91819424", "93441116"),
        (2_000_000_000, "69279037", "90698825", "38618901"),
        (20_000_000_000, "65353130", "77737706", "47863826"),
    ]

    @Test(arguments: TOTPTests.vectors.indices)
    func rfc6238Vectors(_ index: Int) {
        let vector = Self.vectors[index]
        let date = Date(timeIntervalSince1970: vector.time)
        #expect(TOTP.code(key: Self.sha1Key, at: date, parameters: OTPParameters(algorithm: .sha1, digits: 8)) == vector.sha1)
        #expect(TOTP.code(key: Self.sha256Key, at: date, parameters: OTPParameters(algorithm: .sha256, digits: 8)) == vector.sha256)
        #expect(TOTP.code(key: Self.sha512Key, at: date, parameters: OTPParameters(algorithm: .sha512, digits: 8)) == vector.sha512)
    }

    @Test func rfc4226HOTPVectors() {
        let expected = ["755224", "287082", "359152", "969429", "338314", "254676", "287922", "162583", "399871", "520489"]
        for (counter, code) in expected.enumerated() {
            #expect(TOTP.hotp(key: Self.sha1Key, counter: UInt64(counter), digits: 6, algorithm: .sha1) == code)
        }
    }

    @Test func sixDigitCodesKeepLeadingZeros() {
        // 1111111109 is 07081804 at eight digits, so 081804 at six.
        let code = TOTP.code(key: Self.sha1Key, at: Date(timeIntervalSince1970: 1_111_111_109), parameters: OTPParameters())
        #expect(code == "081804")
    }

    @Test func validityIsThePeriodContainingTheDate() {
        let validity = TOTP.validity(at: Date(timeIntervalSince1970: 1_000_000_015), period: 30)
        #expect(validity.lowerBound == Date(timeIntervalSince1970: 999_999_990))
        #expect(validity.upperBound == Date(timeIntervalSince1970: 1_000_000_020))
        let sixty = TOTP.validity(at: Date(timeIntervalSince1970: 1_000_000_015), period: 60)
        #expect(sixty.lowerBound == Date(timeIntervalSince1970: 999_999_960))
    }

    @Test func codeChangesAtThePeriodBoundary() {
        let parameters = OTPParameters()
        let before = TOTP.code(key: Self.sha1Key, at: Date(timeIntervalSince1970: 29), parameters: parameters)
        let after = TOTP.code(key: Self.sha1Key, at: Date(timeIntervalSince1970: 30), parameters: parameters)
        #expect(before != after)
        #expect(before == TOTP.code(key: Self.sha1Key, at: Date(timeIntervalSince1970: 0), parameters: parameters))
    }
}
