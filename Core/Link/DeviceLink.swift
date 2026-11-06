import Foundation

/// This iPhone's link to a Qeet ID account: what the server issued when the pairing code was claimed.
///
/// `deviceToken` is a **long-lived credential**: it approves sign-ins for 180 days after the iPhone was last linked,
/// with no signed-in session. It lives only in the Keychain and in the bodies of the calls that need it; printing a
/// link never shows it.
struct DeviceLink: Codable, Equatable, Sendable {
    /// The account's user id on the server.
    let userID: UUID
    /// This iPhone's id on the server, which it needs to remove itself.
    let deviceID: UUID
    let deviceToken: String
    let linkedAt: Date
    var deviceName: String
    /// The account's email, when the server said it.
    var accountEmail: String?
    /// The APNs token the server last received, in hex.
    var pushToken: String?

    /// How long the server accepts the credential after a link.
    static let lifetime: TimeInterval = 180 * 24 * 60 * 60

    var linkedUntil: Date { linkedAt.addingTimeInterval(Self.lifetime) }

    /// What the screens may show: no credential in it.
    var summary: LinkSummary {
        LinkSummary(deviceName: deviceName, accountEmail: accountEmail, linkedUntil: linkedUntil)
    }
}

extension DeviceLink: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "DeviceLink(device: \(deviceID), credential: <redacted>)" }
    var debugDescription: String { description }
}

/// A link as the screens show it.
struct LinkSummary: Equatable, Sendable {
    var deviceName: String
    var accountEmail: String?
    var linkedUntil: Date
}

/// The device link in the Keychain: one item, readable from the first unlock after a restart, so a push-token update
/// can run in the background; never synced or backed up.
struct DeviceLinkStore: Sendable {
    static let service = "com.qeetgroup.qeetid.device-link"
    private static let account = "current"

    private let keychain: Keychain

    init(service: String = Self.service, accessGroup: String? = AppIdentity.keychainGroup) {
        keychain = Keychain(service: service, accessGroup: accessGroup, accessibility: .afterFirstUnlock)
    }

    func load() throws(KeychainError) -> DeviceLink? {
        guard let data = try keychain.value(account: Self.account) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DeviceLink.self, from: data)
    }

    func save(_ link: DeviceLink) throws(KeychainError) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(link) else { throw KeychainError(status: errSecParam) }
        try keychain.set(data, account: Self.account)
    }

    func clear() throws(KeychainError) {
        try keychain.delete(account: Self.account)
    }
}
