import Foundation

/// RFC 4648 Base32, the alphabet setup keys are written in.
enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    private static let values: [Character: UInt8] = Dictionary(
        uniqueKeysWithValues: alphabet.enumerated().map { ($0.element, UInt8($0.offset)) })

    /// The bytes a key encodes, or `nil` when it isn't Base32. As people type and sites print keys: case, spaces,
    /// hyphens and `=` padding don't matter.
    static func decode(_ text: String) -> Data? {
        var bits: UInt32 = 0
        var count = 0
        var bytes = Data()
        bytes.reserveCapacity(text.count * 5 / 8)
        var sawPadding = false
        for character in text.uppercased() {
            if character == " " || character == "-" || character == "\t" || character == "\n" { continue }
            if character == "=" {
                sawPadding = true
                continue
            }
            // Characters after padding mean it isn't Base32.
            guard !sawPadding, let value = values[character] else { return nil }
            bits = (bits << 5) | UInt32(value)
            count += 5
            if count >= 8 {
                count -= 8
                bytes.append(UInt8((bits >> UInt32(count)) & 0xFF))
            }
        }
        return bytes
    }

    /// `data` in Base32, without padding: for showing a key back, never for storing it.
    static func encode(_ data: Data) -> String {
        var output = ""
        var bits: UInt32 = 0
        var count = 0
        for byte in data {
            bits = (bits << 8) | UInt32(byte)
            count += 8
            while count >= 5 {
                count -= 5
                output.append(alphabet[Int((bits >> UInt32(count)) & 31)])
            }
        }
        if count > 0 {
            output.append(alphabet[Int((bits << UInt32(5 - count)) & 31)])
        }
        return output
    }
}
