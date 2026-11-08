import Foundation
import Testing

@testable import QeetID

/// A passkey prompt with a fixed answer, which remembers what it was asked.
@MainActor
final class FakePasskeys: PasskeyPrompting {
    var result: PasskeyResult
    private(set) var asked: [Data] = []

    init(result: PasskeyResult = .signed(Data(#"{"id":"cred","type":"public-key","response":{}}"#.utf8))) {
        self.result = result
    }

    func sign(_ options: Data) async -> PasskeyResult {
        asked.append(options)
        return result
    }
}

extension SerializedTests {
    /// Administration's own session against canned answers: a passkey sign-in, organisations, renewal, step-up.
    @Suite(.serialized)
    @MainActor
    struct AdminSessionTests {
        /// A Qeet ID stand-in for the administration routes, by path: access tokens `a1` and `a2`; `a1` expires when
        /// `expired` is set; refreshing gives `a2`.
        final class FakeQeetID: @unchecked Sendable {
            var organizations = #"[{"id":"t1","name":"Brightleaf Foods","roles":["Administrator"]}]"#
            var expired = false
            var refreshRefused = false

            func reply(_ request: StubURLProtocol.Recorded) -> StubURLProtocol.Reply {
                let bearer = request.headers["Authorization"]
                let signedIn = bearer == "Bearer a2" || (bearer == "Bearer a1" && !expired)
                switch request.path {
                case "/v1/passkeys/login/begin":
                    return .init(status: 200, json: #"{"session_id":"c1","publicKey":{"challenge":"YWJj","rpId":"id.qeet.in"}}"#)
                case "/v1/passkeys/login/finish":
                    return .init(status: 201, json: #"{"access_token":"a1","refresh_token":"r1"}"#)
                case "/v1/auth/refresh":
                    return refreshRefused
                        ? .init(status: 401, json: #"{"error":{"code":"auth.session_revoked"}}"#)
                        : .init(status: 200, json: #"{"access_token":"a2","refresh_token":"r2"}"#)
                default:
                    break
                }
                guard signedIn else { return .init(status: 401, json: #"{"error":{"code":"unauthorized"}}"#) }
                switch request.path {
                case "/v1/me": return .init(status: 200, json: #"{"email":"meera@brightleaffoods.in"}"#)
                case "/v1/me/organizations": return .init(status: 200, json: #"{"items":\#(organizations),"next_cursor":""}"#)
                case "/v1/auth/switch-tenant": return .init(status: 200, json: #"{"access_token":"a2","refresh_token":"r2"}"#)
                case "/v1/auth/session": return .init(status: 204)
                case "/v1/tenants/t1/agents":
                    return .init(status: 200, json: #"{"items":[{"id":"g1","disabled":false},{"id":"g2","disabled":true}]}"#)
                default: return .init(status: 404, json: "{}")
                }
            }
        }

        let qeetID = FakeQeetID()
        let passkeys = FakePasskeys()
        let session: AdminSession

        init() {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StubURLProtocol.self]
            let api = AdminAPI(baseURL: URL(string: "https://api.test")!, session: URLSession(configuration: configuration))
            let keychain = Keychain(service: "com.qeetgroup.qeetid.tests.admin", accessGroup: nil, accessibility: .whenUnlocked)
            try? keychain.deleteAll()
            session = AdminSession(api: api, keychain: keychain)
            let fake = qeetID
            StubURLProtocol.reply { fake.reply($0) }
        }

        @Test func aPasskeySignInListsTheOrganisationsThePersonAdministers() async {
            qeetID.organizations = #"[{"id":"t1","name":"Brightleaf Foods","roles":["Administrator"]},{"id":"t2","name":"Own","roles":[]}]"#
            let outcome = await session.signIn(with: passkeys)
            guard case .signedIn(let organizations) = outcome else { Issue.record("not signed in: \(outcome)"); return }
            #expect(organizations.map(\.id) == ["t1"])
            #expect(String(data: passkeys.asked.first ?? Data(), encoding: .utf8)?.contains("id.qeet.in") == true)
            #expect(session.summary?.email == "meera@brightleaffoods.in")
            #expect(session.summary?.organizationId == nil)
        }

        @Test func someoneWhoAdministersNothingIsSignedOutAgain() async {
            qeetID.organizations = #"[{"id":"t2","name":"Own","roles":[]}]"#
            #expect(await session.signIn(with: passkeys) == .notAnAdministrator)
            #expect(session.summary == nil)
            #expect(StubURLProtocol.requests.contains { $0.method == "DELETE" && $0.path == "/v1/auth/session" })
        }

        @Test func aCancelledPasskeyChangesNothing() async {
            passkeys.result = .cancelled
            #expect(await session.signIn(with: passkeys) == .cancelled)
            #expect(!StubURLProtocol.requests.contains { $0.path == "/v1/passkeys/login/finish" })
        }

        @Test func choosingAnOrganisationScopesTheSession() async {
            guard case .signedIn(let organizations) = await session.signIn(with: passkeys) else { Issue.record("not signed in"); return }
            guard case .ok = await session.choose(organizations[0]) else { Issue.record("not chosen"); return }
            #expect(session.summary?.organizationName == "Brightleaf Foods")
            let api = session.api
            let running = await session.inOrganization { await api.runningAgents($0, tenant: $1) }
            #expect(running.value == 1)
        }

        @Test func anExpiredAccessTokenIsRenewedOnce() async {
            _ = await session.signIn(with: passkeys)
            qeetID.expired = true
            #expect(await session.organizations().value?.count == 1)
            #expect(StubURLProtocol.requests.contains { $0.path == "/v1/auth/refresh" })
        }

        @Test func aSessionQeetIDEndedIsForgotten() async {
            _ = await session.signIn(with: passkeys)
            qeetID.expired = true
            qeetID.refreshRefused = true
            #expect(await session.organizations().isSignedOut)
            #expect(session.summary == nil)
        }
    }
}
