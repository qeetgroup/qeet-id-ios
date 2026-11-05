import Foundation

/// What claiming a pairing code returns: whose account the iPhone now answers for, its id and its credential.
struct PairingClaim: Decodable, Sendable {
    struct Device: Decodable, Sendable {
        let id: UUID
        let name: String?
    }

    struct Account: Decodable, Sendable {
        let email: String?
    }

    let userID: UUID
    let device: Device
    let deviceToken: String
    let account: Account?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case device
        case deviceToken = "device_token"
        case account
    }
}

/// A sign-in waiting for this iPhone's answer, as the server describes it. It never includes the number: that is
/// shown only where the sign-in happens.
struct SignInChallenge: Decodable, Equatable, Identifiable, Sendable {
    enum Status: String, Sendable {
        case pending, approved, denied, expired, unknown
    }

    /// Where the sign-in comes from.
    struct Context: Decodable, Equatable, Sendable {
        var ip: String?
        var userAgent: String?
        var location: String?
        var timestamp: String?

        enum CodingKeys: String, CodingKey {
            case ip
            case userAgent = "user_agent"
            case location
            case timestamp
        }
    }

    let id: UUID
    let action: String
    let status: Status
    let expiresAt: Date
    let createdAt: Date
    let context: Context

    enum CodingKeys: String, CodingKey {
        case id, action, status, context
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }

    init(id: UUID, action: String, status: Status, expiresAt: Date, createdAt: Date, context: Context) {
        self.id = id
        self.action = action
        self.status = status
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.context = context
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        action = try container.decodeIfPresent(String.self, forKey: .action) ?? "sign_in"
        status = Status(rawValue: try container.decode(String.self, forKey: .status)) ?? .unknown
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        context = (try? container.decodeIfPresent(Context.self, forKey: .context)) ?? Context()
    }

    /// When the sign-in happened, by the server's account of it.
    var signedInAt: Date {
        context.timestamp.flatMap(ServerDate.parse) ?? createdAt
    }
}

/// A challenge with the time it ends by this iPhone's clock: the server's expiry, corrected by the difference
/// between the server's clock and the phone's, so the countdown is right even when the phone's clock is not.
struct FetchedChallenge: Equatable, Sendable {
    let challenge: SignInChallenge
    let expiresAtLocal: Date

    /// Answerable now: pending, and not yet past its time.
    func isOpen(at now: Date) -> Bool {
        challenge.status == .pending && now < expiresAtLocal
    }
}

/// What unlinking found.
enum UnlinkOutcome: Equatable, Sendable {
    /// The server removed this iPhone.
    case removed
    /// The server had already forgotten it (unlinked from the console, or expired).
    case alreadyRemoved
}
