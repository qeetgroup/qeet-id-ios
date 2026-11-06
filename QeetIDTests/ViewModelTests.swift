import Foundation
import Testing

@testable import QeetID

extension SerializedTests {
    /// The models behind the screens, with the Keychain in test services, canned API answers and a stubbed Face ID.
    @MainActor
    @Suite(.serialized)
    struct ViewModelTests {
        let accountStore = KeychainAccountStore(service: "com.qeetgroup.qeetid.account.tests")
        let linkStore = DeviceLinkStore(service: "com.qeetgroup.qeetid.device-link.tests")
        let defaults: UserDefaults

        init() throws {
            try accountStore.deleteAll()
            try linkStore.clear()
            defaults = UserDefaults(suiteName: "com.qeetgroup.qeetid.tests")!
            defaults.removePersistentDomain(forName: "com.qeetgroup.qeetid.tests")
        }

        // MARK: - Accounts

        @Test func accountsAddRenameSearchDelete() throws {
            // A clock that moves on a little each time it's read, inside one 30-second period (30 to 59).
            var seconds: TimeInterval = 31
            let model = AccountsModel(
                store: accountStore,
                now: {
                    seconds += 0.01
                    return Date(timeIntervalSince1970: seconds)
                })
            model.load()
            #expect(model.accounts.isEmpty)
            let github = try model.add(
                AccountDraft(
                    issuer: "GitHub", name: "brightleaf-foods", secret: try SetupKey.decode("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"),
                    parameters: OTPParameters()))
            try model.add(
                AccountDraft(issuer: "AWS", name: "billing", secret: try SetupKey.decode("JBSWY3DPEHPK3PXP"), parameters: OTPParameters()))
            #expect(model.accounts.map(\.issuer) == ["GitHub", "AWS"])
            #expect(model.codes[github.id]?.code == "287082")

            model.query = "aws"
            #expect(model.visibleAccounts.map(\.issuer) == ["AWS"])
            model.query = "brightleaf"
            #expect(model.visibleAccounts.map(\.issuer) == ["GitHub"])
            model.query = ""

            model.rename(github, issuer: "GitHub (work)", name: "  brightleaf-foods ")
            #expect(model.accounts.first?.issuer == "GitHub (work)")
            #expect(model.accounts.first?.name == "brightleaf-foods")
            // An empty issuer keeps the old one.
            model.rename(try #require(model.accounts.first), issuer: " ", name: "x")
            #expect(model.accounts.first?.issuer == "GitHub (work)")

            model.delete(try #require(model.accounts.first))
            #expect(model.accounts.map(\.issuer) == ["AWS"])
        }

        @Test func noCodesWhileSuspended() throws {
            let model = AccountsModel(store: accountStore)
            try model.add(
                AccountDraft(issuer: "GitHub", name: "", secret: try SetupKey.decode("JBSWY3DPEHPK3PXP"), parameters: OTPParameters()))
            #expect(!model.codes.isEmpty)
            model.suspend()
            #expect(model.codes.isEmpty)
            model.refreshCodes()
            #expect(model.codes.isEmpty)
            model.resume()
            #expect(!model.codes.isEmpty)
        }

        // MARK: - App lock

        @Test func lockNeedsTheOwnerToTurnOffAndUnlock() async {
            let preferences = Preferences(defaults: defaults)
            let lock = AppLock(preferences: preferences, authenticator: StubDeviceOwnerAuthenticator(outcome: .success))
            #expect(!lock.isLocked)
            #expect(await lock.enable() == .success)
            lock.lock()
            #expect(lock.isLocked)
            await lock.unlock()
            #expect(!lock.isLocked)

            let failing = AppLock(preferences: preferences, authenticator: StubDeviceOwnerAuthenticator(outcome: .failed))
            #expect(failing.isLocked)
            await failing.unlock()
            #expect(failing.isLocked)
            #expect(failing.lastOutcome == .failed)
            #expect(await failing.disable() == .failed)
            #expect(preferences.isLockEnabled)
        }

        @Test func theShieldCoversWhenLockedOrNotActive() {
            let preferences = Preferences(defaults: defaults)
            preferences.isLockEnabled = true
            let model = AppModel(
                preferences: preferences, authenticator: StubDeviceOwnerAuthenticator(outcome: .success), accountStore: accountStore,
                linkStore: linkStore)
            #expect(model.shield == .locked)
            preferences.isLockEnabled = false
            let open = AppModel(
                preferences: preferences, authenticator: StubDeviceOwnerAuthenticator(outcome: .success), accountStore: accountStore,
                linkStore: linkStore)
            #expect(open.shield == .none)
            open.scenePhaseChanged(to: .inactive)
            #expect(open.shield == .privacy)
            open.scenePhaseChanged(to: .active)
            #expect(open.shield == .none)
        }

        // MARK: - Sign-in requests

        private func linkedModels(auth: AuthenticationOutcome = .success) throws -> (LinkModel, AppLock) {
            try linkStore.save(SerializedTests.APIClientTests.link)
            let link = LinkModel(store: linkStore, push: PushRegistrar(), client: { StubURLProtocol.client() })
            link.load()
            let lock = AppLock(preferences: Preferences(defaults: defaults), authenticator: StubDeviceOwnerAuthenticator(outcome: auth))
            return (link, lock)
        }

        private func openChallenge(seconds: TimeInterval = 120) -> FetchedChallenge {
            FetchedChallenge(
                challenge: SignInChallenge(
                    id: SerializedTests.APIClientTests.challengeID, action: "sign_in", status: .pending,
                    expiresAt: Date().addingTimeInterval(seconds),
                    createdAt: Date(),
                    context: .init(userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/131.0 Safari/537.36")),
                expiresAtLocal: Date().addingTimeInterval(seconds))
        }

        @Test func approvingNeedsTwoDigits() async throws {
            let (link, lock) = try linkedModels()
            StubURLProtocol.reply { _ in .init(status: 200, json: #"{"status":"approved"}"#) }
            let model = SignInRequestModel(
                id: SerializedTests.APIClientTests.challengeID, prefetched: openChallenge(), link: link, lock: lock,
                client: { StubURLProtocol.client() })
            model.number = "4"
            await model.approve()
            #expect(model.numberError != nil)
            #expect(StubURLProtocol.requests.isEmpty)
            model.number = "47"
            #expect(model.numberError == nil)
            await model.approve()
            #expect(model.phase == .outcome(.approved(browser: "Chrome on macOS")))
            #expect(StubURLProtocol.requests.first?.json["number"] as? Int == 47)
        }

        @Test func approvingNeedsTheOwner() async throws {
            let (link, lock) = try linkedModels(auth: .failed)
            StubURLProtocol.reply { _ in .init(status: 200) }
            let model = SignInRequestModel(
                id: SerializedTests.APIClientTests.challengeID, prefetched: openChallenge(), link: link, lock: lock,
                client: { StubURLProtocol.client() })
            model.number = "47"
            await model.approve()
            #expect(StubURLProtocol.requests.isEmpty)
            #expect(model.numberError != nil)
            if case .review = model.phase {} else { Issue.record("Still under review") }
        }

        @Test func aWrongNumberEndsTheRequest() async throws {
            let (link, lock) = try linkedModels()
            StubURLProtocol.reply { _ in .init(status: 403, json: #"{"error":{"code":"mfa.push_number_mismatch"}}"#) }
            let model = SignInRequestModel(
                id: SerializedTests.APIClientTests.challengeID, prefetched: openChallenge(), link: link, lock: lock,
                client: { StubURLProtocol.client() })
            model.number = "12"
            await model.approve()
            #expect(model.phase == .outcome(.ended(.numberMismatch)))
        }

        @Test func denyingBlocksWithoutFaceID() async throws {
            let (link, lock) = try linkedModels(auth: .failed)
            StubURLProtocol.reply { _ in .init(status: 200, json: #"{"status":"denied"}"#) }
            let model = SignInRequestModel(
                id: SerializedTests.APIClientTests.challengeID, prefetched: openChallenge(), link: link, lock: lock,
                client: { StubURLProtocol.client() })
            await model.deny()
            #expect(model.phase == .outcome(.denied))
        }

        @Test func requestsEnd() async throws {
            let (link, lock) = try linkedModels()
            let expired = SignInRequestModel(
                id: SerializedTests.APIClientTests.challengeID, prefetched: openChallenge(seconds: -1), link: link, lock: lock,
                client: { StubURLProtocol.client() })
            #expect(expired.phase == .outcome(.ended(.expired)))

            let open = SignInRequestModel(
                id: SerializedTests.APIClientTests.challengeID, prefetched: openChallenge(seconds: 0.2), link: link, lock: lock)
            try await Task.sleep(for: .milliseconds(300))
            open.expireIfDue()
            #expect(open.phase == .outcome(.ended(.expired)))

            StubURLProtocol.reply { _ in .init(status: 0, error: URLError(.notConnectedToInternet)) }
            let offline = SignInRequestModel(
                id: SerializedTests.APIClientTests.challengeID, link: link, lock: lock, client: { StubURLProtocol.client() })
            await offline.load()
            #expect(offline.phase == .failedToLoad(.offline))

            StubURLProtocol.reply { _ in
                .init(
                    status: 200,
                    json: SerializedTests.APIClientTests.challengeJSON.replacingOccurrences(of: "\"pending\"", with: "\"approved\""))
            }
            let answered = SignInRequestModel(
                id: SerializedTests.APIClientTests.challengeID, link: link, lock: lock, client: { StubURLProtocol.client() })
            await answered.load()
            #expect(answered.phase == .outcome(.ended(.answered)))
        }

        @Test func aStaleLinkIsNoticed() async throws {
            let (link, _) = try linkedModels()
            StubURLProtocol.reply { _ in .init(status: 401, json: #"{"error":{"code":"mfa.push_unauthorized"}}"#) }
            #expect(await link.pendingRequests().isEmpty)
            #expect(link.isStale)
            StubURLProtocol.reply { _ in .init(status: 200, json: #"{"challenges":[]}"#) }
            _ = await link.pendingRequests()
            #expect(!link.isStale)
        }

        @Test func aBare401KeepsTheLink() async throws {
            let (link, _) = try linkedModels()
            StubURLProtocol.reply { _ in .init(status: 401, json: "") }
            #expect(await link.pendingRequests().isEmpty)
            #expect(!link.isStale)
            await #expect(throws: APIError.server(status: 401, code: nil)) { try await link.unlink() }
            #expect(link.isLinked)
            #expect(try linkStore.load() != nil)
            await link.pushTokenChanged("cafe")
            #expect(!link.isStale)
            #expect(try linkStore.load()?.pushToken == SerializedTests.APIClientTests.link.pushToken)
        }

        @Test func qeetIDsOwn401MeansTheLinkIsGone() async throws {
            let (link, _) = try linkedModels()
            StubURLProtocol.reply { _ in .init(status: 401, json: #"{"error":{"code":"mfa.push_unauthorized"}}"#) }
            #expect(try await link.unlink() == .alreadyRemoved)
            #expect(!link.isLinked)
            #expect(try linkStore.load() == nil)
        }

        @Test func unlinkingClearsOnlyWhenTheServerAgrees() async throws {
            let (link, _) = try linkedModels()
            StubURLProtocol.reply { _ in .init(status: 0, error: URLError(.notConnectedToInternet)) }
            await #expect(throws: APIError.offline) { try await link.unlink() }
            #expect(link.isLinked)
            StubURLProtocol.reply { _ in .init(status: 204) }
            #expect(try await link.unlink() == .removed)
            #expect(!link.isLinked)
            #expect(try linkStore.load() == nil)
        }
    }
}
