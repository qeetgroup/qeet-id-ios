import Foundation
import Observation

/// Who is signed in to administration, and in which organisation, as the screens show it.
struct AdminSummary: Equatable, Sendable {
    let email: String
    let organizationId: String?
    let organizationName: String?
}

/// How signing in went.
enum SignInOutcome: Equatable, Sendable {
    /// Signed in; `organizations` are the ones the person has a role in.
    case signedIn([Organization])
    /// Signed in, but they administer no organisation: signed out again.
    case notAnAdministrator
    case cancelled
    case passkeyUnavailable
    case network
    case refused
}

/// How a step-up went.
enum StepUpOutcome: Equatable, Sendable {
    case done, cancelled, unavailable, signedOut, network, refused
}

/// The administrator's own Qeet ID session on this iPhone, apart from the iPhone's link (which approves sign-ins and
/// holds no session). It signs in with a passkey, keeps the refresh token in the Keychain (this device only, never
/// synced, not shared with the extensions) and the access token in memory only, renews it when it runs out, and runs
/// each administration call with it. A step-up (a fresh passkey check) goes before anything that gives or takes access.
@MainActor
@Observable
final class AdminSession {
    /// Who is signed in, and where; nil when nobody is.
    private(set) var summary: AdminSummary?

    @ObservationIgnored let api: AdminAPI
    @ObservationIgnored private let keychain: Keychain
    @ObservationIgnored private var access: String?

    private struct Stored: Codable {
        var refreshToken: String
        var email: String
        var organizationId: String?
        var organizationName: String?
    }

    private static let account = "admin-session"

    init(
        api: AdminAPI = AdminAPI(),
        keychain: Keychain = Keychain(service: "com.qeetgroup.qeetid.admin", accessGroup: nil, accessibility: .whenUnlocked)
    ) {
        self.api = api
        self.keychain = keychain
    }

    /// Reads the stored session, so `summary` is right when Settings shows.
    func load() async {
        publish(read())
    }

    /// Signs in with a passkey; on success the session is in the person's own organisation until one is chosen.
    func signIn(with passkeys: any PasskeyPrompting) async -> SignInOutcome {
        let ceremony: Ceremony
        switch await api.beginSignIn() {
        case .ok(let value): ceremony = value
        case .network: return .network
        default: return .refused
        }
        let signed: Data
        switch await passkeys.sign(ceremony.publicKey) {
        case .signed(let data): signed = data
        case .cancelled: return .cancelled
        case .unavailable: return .passkeyUnavailable
        }
        let pair: TokenPair
        switch await api.finishSignIn(ceremony: ceremony.sessionId, credential: signed) {
        case .ok(let value): pair = value
        case .network: return .network
        default: return .refused
        }
        let email = await api.me(pair.accessToken).value?.email ?? ""
        let organizations: [Organization]
        switch await api.organizations(pair.accessToken) {
        case .ok(let list): organizations = list.filter { !$0.roles.isEmpty }
        case .network:
            await api.signOut(pair.accessToken)
            return .network
        default:
            await api.signOut(pair.accessToken)
            return .refused
        }
        guard !organizations.isEmpty else {
            await api.signOut(pair.accessToken)
            return .notAnAdministrator
        }
        store(pair, Stored(refreshToken: pair.refreshToken, email: email))
        return .signedIn(organizations)
    }

    /// The organisations the signed-in person has a role in.
    func organizations() async -> AdminResult<[Organization]> {
        await run { [api] access in await api.organizations(access) }.map { $0.filter { !$0.roles.isEmpty } }
    }

    /// Scopes the session to `organization`: every call after it acts there.
    func choose(_ organization: Organization) async -> AdminResult<Void> {
        let switched = await run { [api] access in await api.switchOrganization(access, to: organization.id) }
        guard case .ok(let pair) = switched else { return switched.map { _ in () } }
        guard var current = read() else { return .signedOut }
        current.refreshToken = pair.refreshToken
        current.organizationId = organization.id
        current.organizationName = organization.name
        store(pair, current)
        return .ok(())
    }

    /// Runs `action` in the chosen organisation, renewing the access token once when it has run out, and forgetting
    /// the session when Qeet ID has ended it.
    func inOrganization<T: Sendable>(_ action: @escaping @Sendable (String, String) async -> AdminResult<T>) async -> AdminResult<T> {
        guard let tenant = summary?.organizationId else { return .signedOut }
        return await run { access in await action(access, tenant) }
    }

    /// A fresh passkey check for this session, which Qeet ID asks for before access is given or taken back.
    func stepUp(with passkeys: any PasskeyPrompting) async -> StepUpOutcome {
        let ceremony: Ceremony
        switch await run({ [api] access in await api.beginStepUp(access) }) {
        case .ok(let value): ceremony = value
        case .signedOut: return .signedOut
        case .network: return .network
        default: return .refused
        }
        let signed: Data
        switch await passkeys.sign(ceremony.publicKey) {
        case .signed(let data): signed = data
        case .cancelled: return .cancelled
        case .unavailable: return .unavailable
        }
        switch await run({ [api] access in await api.finishStepUp(access, ceremony: ceremony.sessionId, credential: signed) }) {
        case .ok: return .done
        case .signedOut: return .signedOut
        case .network: return .network
        default: return .refused
        }
    }

    /// Ends the session on Qeet ID and forgets it here, whatever the server answers.
    func signOut() async {
        if let access { await api.signOut(access) }
        forget()
    }

    private func run<T: Sendable>(_ action: @escaping @Sendable (String) async -> AdminResult<T>) async -> AdminResult<T> {
        let token: String
        if let access {
            token = access
        } else if let renewed = await renew() {
            token = renewed
        } else {
            return .signedOut
        }
        let result = await action(token)
        guard result.isSignedOut else { return result }
        // The access token ran out: renew it once and try again.
        guard let renewed = await renew() else { return .signedOut }
        return await action(renewed)
    }

    /// A new access token from the stored refresh token; nil (and the session forgotten) when Qeet ID ended it.
    private func renew() async -> String? {
        guard var stored = read() else { return nil }
        switch await api.refresh(stored.refreshToken) {
        case .ok(let pair):
            stored.refreshToken = pair.refreshToken
            store(pair, stored)
            return pair.accessToken
        case .network:
            return nil
        default:
            forget()
            return nil
        }
    }

    private func store(_ pair: TokenPair, _ stored: Stored) {
        if let data = try? JSONEncoder().encode(stored) {
            try? keychain.set(data, account: Self.account)
        }
        access = pair.accessToken
        publish(stored)
    }

    private func forget() {
        try? keychain.delete(account: Self.account)
        access = nil
        publish(nil)
    }

    private func read() -> Stored? {
        guard let data = try? keychain.value(account: Self.account) else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    private func publish(_ stored: Stored?) {
        summary = stored.map { AdminSummary(email: $0.email, organizationId: $0.organizationId, organizationName: $0.organizationName) }
    }
}
