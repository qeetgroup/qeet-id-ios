import Foundation
import Testing

@testable import QeetID

/// RFC 4648 §10.
struct Base32Tests {
    static let vectors: [(plain: String, encoded: String)] = [
        ("", ""), ("f", "MY"), ("fo", "MZXQ"), ("foo", "MZXW6"), ("foob", "MZXW6YQ"), ("fooba", "MZXW6YTB"), ("foobar", "MZXW6YTBOI"),
    ]

    @Test(arguments: Base32Tests.vectors.indices)
    func roundTrips(_ index: Int) {
        let vector = Self.vectors[index]
        #expect(Base32.encode(Data(vector.plain.utf8)) == vector.encoded)
        #expect(Base32.decode(vector.encoded) == Data(vector.plain.utf8))
    }

    @Test func readsKeysAsPeopleTypeThem() {
        let expected = Base32.decode("JBSWY3DPEHPK3PXP")
        #expect(expected != nil)
        #expect(Base32.decode("jbsw y3dp ehpk 3pxp") == expected)
        #expect(Base32.decode("JBSW-Y3DP-EHPK-3PXP") == expected)
        #expect(Base32.decode("MZXW6YTBOI======") == Data("foobar".utf8))
    }

    @Test func refusesWhatIsNotBase32() {
        #expect(Base32.decode("JBSW1") == nil)  // 1 isn't in the alphabet
        #expect(Base32.decode("MZXW6===YQ") == nil)  // characters after padding
        #expect(Base32.decode("ÄBC") == nil)
    }
}
