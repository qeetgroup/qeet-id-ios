import Foundation

/// The server's timestamps: RFC 3339, with up to nine fractional digits (Go's time.Time).
enum ServerDate {
    static func parse(_ text: String) -> Date? {
        // Keep at most three fractional digits: the formatter reads milliseconds.
        var value = text
        if let dot = value.firstIndex(of: "."),
            let end = value[dot...].firstIndex(where: { $0 == "Z" || $0 == "z" || $0 == "+" || $0 == "-" })
        {
            let digits = value[value.index(after: dot)..<end]
            value.replaceSubrange(
                value.index(after: dot)..<end, with: String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0))
        }
        if let date = try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { return date }
        return try? Date(value, strategy: Date.ISO8601FormatStyle())
    }

    /// The server's clock from a response's `Date` header (RFC 7231), to correct for a phone whose clock is wrong.
    static func fromHTTPHeader(_ text: String?) -> Date? {
        guard let text else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: text)
    }

    static let decoding = JSONDecoder.DateDecodingStrategy.custom { decoder in
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let date = parse(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an RFC 3339 date")
        }
        return date
    }
}
