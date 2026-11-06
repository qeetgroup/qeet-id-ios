import Foundation
import Testing

@testable import QeetID

struct PairingCodeTests {
    @Test func readsTheConsolesLink() {
        #expect(PairingCode.from("qeetidauth://pair?code=KM7QX-4TRWP") == "KM7QX-4TRWP")
        #expect(PairingCode.from("QEETIDAUTH://pair/?code=km7qx4trwp") == "KM7QX-4TRWP")
        #expect(PairingCode.fromLink(URL(string: "qeetidauth://pair?foo=1&code=KM7QX%2D4TRWP")!) == "KM7QX-4TRWP")
    }

    @Test func readsTypedCodesAsTheServerDoes() {
        #expect(PairingCode.from("km7qx 4trwp") == "KM7QX-4TRWP")
        #expect(PairingCode.from("KM7QX4TRWP") == "KM7QX-4TRWP")
        // O, I and L read as 0, 1 and 1.
        #expect(PairingCode.from("O1ILO-ABCDE") == "0111O-ABCDE".replacingOccurrences(of: "O", with: "0"))
    }

    @Test func refusesWhatIsNotACode() {
        #expect(PairingCode.from("KM7QX-4TRW") == nil)  // nine characters
        #expect(PairingCode.from("KM7QX-4TRWU") == nil)  // U isn't Crockford
        #expect(PairingCode.from("otpauth://totp/A:b?secret=JBSWY3DPEHPK3PXP") == nil)
        #expect(PairingCode.from("qeetidauth://other?code=KM7QX-4TRWP") == nil)
        #expect(PairingCode.from("https://evil.example/pair?code=KM7QX-4TRWP") == nil)
    }
}
