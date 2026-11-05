import Foundation
import Observation

/// Why linking didn't happen.
enum LinkError: Error, Equatable {
    case api(APIError)
    /// APNs gave no token: no push entitlement yet, or no network.
    case noPushToken
    /// The Keychain refused the credential.
    case storage
}

/// This iPhone's link to a Qeet ID account. The screens see a `LinkSummary`; the device credential is read from the
/// Keychain inside each call that needs it and never kept here.
@MainActor
@Observable
final class LinkModel {
    private(set) var summary: LinkSummary?
    /// The server no longer accepts this iPhone's credential (unlinked elsewhere, or past its 180 days).
    private(set) var isStale = false

    @ObservationIgnored let push: PushRegistrar
    @ObservationIgnored private let store: DeviceLinkStore
    @ObservationIgnored private let client: @MainActor () -> APIClient

    init(store: DeviceLinkStore, push: PushRegistrar, client: @escaping @MainActor () -> APIClient = { APIClient() }) {
        self.store = store
        self.push = push
        self.client = client
    }

    var isLinked: Bool { summary != nil }

    func load() {
        summary = storedLink()?.summary
    }

    /// Claims `code` for this iPhone, named `name`. A link to another account is removed from the server afterwards,
    /// so that account stops sending requests here.
    @discardableResult
    func link(code: String, name: String) async throws(LinkError) -> LinkSummary {
        guard let pushToken = await push.currentToken() else { throw .noPushToken }
        let previous = storedLink()
        let claim: PairingClaim
        do {
            claim = try await client().claimPairing(code: code, name: name, pushToken: pushToken)
        } catch {
            throw .api(error)
        }
        let link = DeviceLink(
            userID: claim.userID, deviceID: claim.device.id, deviceToken: claim.deviceToken, linkedAt: Date(),
            deviceName: claim.device.name.flatMap { $0.isEmpty ? nil : $0 } ?? name, accountEmail: claim.account?.email,
            pushToken: pushToken)
        do {
            try store.save(link)
        } catch {
            throw .storage
        }
        if let previous, previous.deviceID != link.deviceID || previous.userID != link.userID {
            let client = client()
            Task { _ = try? await client.unlink(previous) }
        }
        summary = link.summary
        isStale = false
        Log.push.info("Linked this iPhone")
        return link.summary
    }

    /// Removes this iPhone from the account on the server, then here. If the server can't be reached, the link stays.
    func unlink() async throws(APIError) -> UnlinkOutcome {
        guard let link = storedLink() else {
            summary = nil
            return .alreadyRemoved
        }
        let outcome = try await client().unlink(link)
        try? store.clear()
        summary = nil
        isStale = false
        return outcome
    }

    /// The requests waiting for this iPhone, newest first; none when the server doesn't list them yet.
    func pendingRequests() async -> [FetchedChallenge] {
        guard let link = storedLink() else { return [] }
        do {
            let pending = try await client().pendingChallenges(for: link)
            isStale = false
            return pending
        } catch .unauthorized {
            isStale = true
            return []
        } catch {
            return []
        }
    }

    /// Answers a request with this iPhone's credential.
    func respond(to id: UUID, approved: Bool, number: Int?) async throws(APIError) {
        guard let link = storedLink() else { throw .unauthorized }
        do {
            try await client().respond(to: id, approved: approved, number: number, link: link)
        } catch .unauthorized {
            isStale = true
            throw .unauthorized
        }
    }

    /// APNs gave a new token: tell the server, so requests keep arriving. Tolerates a server without the route.
    func pushTokenChanged(_ token: String) async {
        guard var link = storedLink(), link.pushToken != token else { return }
        do {
            try await client().updatePushToken(token, for: link)
            link.pushToken = token
            try? store.save(link)
        } catch .unauthorized {
            isStale = true
        } catch {
            Log.push.notice("Couldn't send the new APNs token: \(String(describing: error), privacy: .public)")
        }
    }

    private func storedLink() -> DeviceLink? {
        do {
            return try store.load()
        } catch {
            Log.storage.error("Couldn't read the device link")
            return nil
        }
    }
}
