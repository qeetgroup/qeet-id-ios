import Foundation
import Testing

@testable import QeetID

struct OTPAuthURITests {
    @Test func readsAFullLink() throws {
        let draft = try OTPAuthURI.parse(
            "otpauth://totp/GitHub:brightleaf-foods?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA256&digits=8&period=60")
        #expect(draft.issuer == "GitHub")
        #expect(draft.name == "brightleaf-foods")
        #expect(draft.secret == Base32.decode("JBSWY3DPEHPK3PXP"))
        #expect(draft.parameters == OTPParameters(algorithm: .sha256, digits: 8, period: 60))
    }

    @Test func defaultsToSHA1SixDigitsThirtySeconds() throws {
        let draft = try OTPAuthURI.parse("otpauth://totp/Qeet%20ID:meera@brightleaffoods.in?secret=JBSWY3DPEHPK3PXP")
        #expect(draft.issuer == "Qeet ID")
        #expect(draft.name == "meera@brightleaffoods.in")
        #expect(draft.parameters == OTPParameters())
    }

    @Test func issuerParameterWinsOverTheLabel() throws {
        let draft = try OTPAuthURI.parse("otpauth://totp/Old:billing@brightleaffoods.in?secret=JBSWY3DPEHPK3PXP&issuer=AWS")
        #expect(draft.issuer == "AWS")
        #expect(draft.name == "billing@brightleaffoods.in")
    }

    @Test func aLabelWithoutAnIssuerBecomesTheIssuer() throws {
        let draft = try OTPAuthURI.parse("otpauth://totp/Zoho%20Books?secret=JBSWY3DPEHPK3PXP")
        #expect(draft.issuer == "Zoho Books")
        #expect(draft.name == "")
    }

    @Test func toleratesUnencodedSpacesAndLowercase() throws {
        let draft = try OTPAuthURI.parse("OTPAUTH://TOTP/Zoho Books:Brightleaf Foods Pvt Ltd?secret=jbswy3dpehpk3pxp&algorithm=sha1")
        #expect(draft.issuer == "Zoho Books")
        #expect(draft.name == "Brightleaf Foods Pvt Ltd")
    }

    @Test func refusesWhatIsNotATimeBasedCode() {
        #expect(throws: SetupKeyError.counterBased) { try OTPAuthURI.parse("otpauth://hotp/A:b?secret=JBSWY3DPEHPK3PXP&counter=1") }
        #expect(throws: SetupKeyError.transferQR) { try OTPAuthURI.parse("otpauth-migration://offline?data=abc") }
        #expect(throws: SetupKeyError.notACodeQR) { try OTPAuthURI.parse("https://github.com/login") }
        #expect(throws: SetupKeyError.notACodeQR) { try OTPAuthURI.parse("qeetidauth://pair?code=KM7QX-4TRWP") }
    }

    @Test func refusesBadKeysAndSettings() {
        #expect(throws: SetupKeyError.keyMissing) { try OTPAuthURI.parse("otpauth://totp/A:b?issuer=A") }
        #expect(throws: SetupKeyError.keyInvalid) { try OTPAuthURI.parse("otpauth://totp/A:b?secret=JBSW1DPEHPK3PXP0") }
        #expect(throws: SetupKeyError.keyTooShort) { try OTPAuthURI.parse("otpauth://totp/A:b?secret=JBSWY3DP") }
        #expect(throws: SetupKeyError.unsupportedSettings) { try OTPAuthURI.parse("otpauth://totp/A:b?secret=JBSWY3DPEHPK3PXP&digits=7") }
        #expect(throws: SetupKeyError.unsupportedSettings) {
            try OTPAuthURI.parse("otpauth://totp/A:b?secret=JBSWY3DPEHPK3PXP&algorithm=MD5")
        }
        #expect(throws: SetupKeyError.unsupportedSettings) { try OTPAuthURI.parse("otpauth://totp/A:b?secret=JBSWY3DPEHPK3PXP&period=0") }
    }

    @Test func setupKeysAsTyped() throws {
        #expect(try SetupKey.decode("JBSW Y3DP EHPK 3PXP") == Base32.decode("JBSWY3DPEHPK3PXP"))
        #expect(throws: SetupKeyError.keyMissing) { try SetupKey.decode("   ") }
        #expect(throws: SetupKeyError.keyTooShort) { try SetupKey.decode("JBSWY3DP") }
        #expect(throws: SetupKeyError.keyInvalid) { try SetupKey.decode("JBSWY3DPEHPK3PX!") }
    }

    @Test func everyRefusalSaysWhatToDo() {
        let errors: [SetupKeyError] = [
            .notACodeQR, .counterBased, .transferQR, .keyMissing, .keyInvalid, .keyTooShort, .unsupportedSettings,
        ]
        for error in errors { #expect(!error.message.isEmpty) }
    }
}
