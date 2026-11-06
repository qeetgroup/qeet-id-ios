import Foundation

/// What went wrong talking to Qeet ID, in the terms the screens act on. The server's own words and codes stay out of
/// the screens: each case has the app's sentence.
enum APIError: Error, Equatable, Sendable {
    /// No internet connection.
    case offline
    /// The server couldn't be reached: a timeout, a DNS or TLS failure.
    case unreachable
    case cancelled
    /// A pairing code that is wrong, already used, withdrawn or expired (the server doesn't tell them apart).
    case pairingCodeInvalid
    /// Too many tries; wait this many seconds.
    case throttled(retryAfter: Int)
    /// The request is unknown to the server.
    case notFound
    /// The request is past its two minutes.
    case challengeExpired
    /// The request was already answered.
    case challengeAnswered
    /// The number typed isn't the one on the sign-in screen, so the server denied the request.
    case numberMismatch
    /// Qeet ID refused the device credential (a 401 carrying `mfa.push_unauthorized`): the iPhone was unlinked or its
    /// link expired. A 401 without that code is `.server`, and never costs the iPhone its link.
    case unauthorized
    /// The server doesn't have this endpoint yet.
    case unsupported
    /// Anything else the server answered.
    case server(status: Int, code: String?)
    /// An answer the app couldn't read.
    case invalidResponse

    /// The sentence for a problem reaching the server, for the screens that show one.
    var connectionMessage: String {
        switch self {
        case .offline: String(localized: "You're offline. Connect to the internet and try again.")
        default: String(localized: "Qeet ID couldn't be reached. Check your connection and try again.")
        }
    }

    init(transport error: any Error) {
        guard let error = error as? URLError else {
            self = .unreachable
            return
        }
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            self = .offline
        case .cancelled:
            self = .cancelled
        default:
            self = .unreachable
        }
    }
}

/// The server's error envelope: `{"error": {"code": "mfa.pairing_code_invalid", "metadata": {...}}}`.
struct ServerErrorEnvelope: Decodable {
    struct Body: Decodable {
        let code: String?
        let metadata: [String: JSONValue]?
    }

    let error: Body?
}

/// Just enough of JSON to read an error's metadata.
enum JSONValue: Decodable, Equatable, Sendable {
    case number(Double)
    case string(String)
    case bool(Bool)
    case other

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else {
            self = .other
        }
    }

    var intValue: Int? {
        switch self {
        case .number(let value): Int(value.rounded(.up))
        case .string(let value): Int(value)
        default: nil
        }
    }
}
