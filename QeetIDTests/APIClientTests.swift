import Foundation
import Testing

@testable import QeetID

extension SerializedTests {
    /// The API client against canned answers: request shapes, credentials only in bodies, and every status the screens act
    /// on.
    @Suite(.serialized)
    struct APIClientTests {
        static let link = DeviceLink(
            userID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            deviceID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, deviceToken: "device-credential", linkedAt: Date(),
            deviceName: "Meera's iPhone")
        static let challengeID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        static let challengeJSON = """
            {"id":"33333333-3333-3333-3333-333333333333","user_id":"11111111-1111-1111-1111-111111111111","action":"sign_in",
             "context":{"ip":"49.205.143.27","user_agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/131.0.0.0 Safari/537.36",
             "location":"Hyderabad, India","timestamp":"2026-11-06T10:47:12.123456Z"},
             "status":"pending","expires_at":"2026-11-06T10:49:12.123456789Z","created_at":"2026-11-06T10:47:12.1Z"}
            """

        let client = StubURLProtocol.client()

        @Test func claimsAPairingCodeWithoutABearer() async throws {
            StubURLProtocol.reply { _ in
                .init(
                    status: 201,
                    json: """
                        {"user_id":"11111111-1111-1111-1111-111111111111","device":{"id":"22222222-2222-2222-2222-222222222222",
                         "name":"Meera's iPhone","platform":"ios"},"device_token":"tok","account":{"email":"meera@brightleaffoods.in"}}
                        """)
            }
            let claim = try await client.claimPairing(code: "KM7QX-4TRWP", name: "Meera's iPhone", pushToken: "a1b2")
            #expect(claim.account?.email == "meera@brightleaffoods.in")
            #expect(claim.deviceToken == "tok")
            let request = try #require(StubURLProtocol.requests.first)
            #expect(request.method == "POST")
            #expect(request.path == "/v1/mfa/push/pairing/claim")
            #expect(request.headers["Authorization"] == nil)
            #expect(request.json["code"] as? String == "KM7QX-4TRWP")
            #expect(request.json["push_token"] as? String == "a1b2")
            #expect(request.json["platform"] as? String == "ios")
            #expect(request.json["name"] as? String == "Meera's iPhone")
        }

        @Test func aClaimWithoutTheAccountStillLinks() async throws {
            StubURLProtocol.reply { _ in
                .init(
                    status: 201,
                    json:
                        #"{"user_id":"11111111-1111-1111-1111-111111111111","device":{"id":"22222222-2222-2222-2222-222222222222"},"device_token":"t"}"#
                )
            }
            let claim = try await client.claimPairing(code: "KM7QX-4TRWP", name: "x", pushToken: "a")
            #expect(claim.account == nil)
        }

        @Test func claimErrors() async {
            StubURLProtocol.reply { _ in .init(status: 401, json: #"{"error":{"code":"mfa.pairing_code_invalid","message":"…"}}"#) }
            await #expect(throws: APIError.pairingCodeInvalid) { try await client.claimPairing(code: "A", name: "b", pushToken: "c") }
            StubURLProtocol.reply { _ in .init(status: 429, json: #"{"error":{"code":"too_many_requests","metadata":{"retry_after":90}}}"#)
            }
            await #expect(throws: APIError.throttled(retryAfter: 90)) {
                try await client.claimPairing(code: "A", name: "b", pushToken: "c")
            }
            StubURLProtocol.reply { _ in .init(status: 429, json: "{}", headers: ["Retry-After": "12"]) }
            await #expect(throws: APIError.throttled(retryAfter: 12)) {
                try await client.claimPairing(code: "A", name: "b", pushToken: "c")
            }
        }

        @Test func readsAChallengeAndCorrectsForTheServerClock() async throws {
            StubURLProtocol.reply { _ in .init(status: 200, json: Self.challengeJSON, headers: ["Date": "Fri, 06 Nov 2026 10:47:12 GMT"]) }
            let fetched = try await client.challenge(Self.challengeID)
            #expect(fetched.challenge.status == .pending)
            #expect(fetched.challenge.context.location == "Hyderabad, India")
            #expect(fetched.challenge.context.browser == "Chrome on macOS")
            // The server says it's 10:47:12 and the request ends two minutes later: two minutes from now, here.
            let left = fetched.expiresAtLocal.timeIntervalSinceNow
            #expect(left > 115 && left < 125)
            let request = try #require(StubURLProtocol.requests.first)
            #expect(request.method == "GET")
            #expect(request.path == "/v1/mfa/push/challenges/33333333-3333-3333-3333-333333333333")
        }

        @Test func anUnknownChallengeIsNotFound() async {
            StubURLProtocol.reply { _ in .init(status: 404, json: #"{"error":{"code":"not_found"}}"#) }
            await #expect(throws: APIError.notFound) { try await client.challenge(Self.challengeID) }
        }

        @Test func approvingSendsTheNumberAndTheCredentialInTheBody() async throws {
            StubURLProtocol.reply { _ in .init(status: 200, json: #"{"status":"approved"}"#) }
            try await client.respond(to: Self.challengeID, approved: true, number: 47, link: Self.link)
            let request = try #require(StubURLProtocol.requests.first)
            #expect(request.path == "/v1/mfa/push/challenges/33333333-3333-3333-3333-333333333333/respond")
            #expect(request.headers["Authorization"] == nil)
            #expect(request.json["user_id"] as? String == "11111111-1111-1111-1111-111111111111")
            #expect(request.json["device_token"] as? String == "device-credential")
            #expect(request.json["approved"] as? Bool == true)
            #expect(request.json["number"] as? Int == 47)
        }

        @Test func denyingSendsNoNumber() async throws {
            StubURLProtocol.reply { _ in .init(status: 200, json: #"{"status":"denied"}"#) }
            try await client.respond(to: Self.challengeID, approved: false, number: 47, link: Self.link)
            let request = try #require(StubURLProtocol.requests.first)
            #expect(request.json["approved"] as? Bool == false)
            #expect(request.json["number"] == nil)
        }

        @Test(arguments: [
            (403, "mfa.push_number_mismatch", APIError.numberMismatch), (410, "mfa.push_challenge_expired", .challengeExpired),
            (409, "mfa.push_challenge_invalid", .challengeAnswered), (401, "mfa.push_unauthorized", .unauthorized),
            (404, "not_found", .challengeExpired), (500, "internal", .server(status: 500, code: "internal")),
        ])
        func respondErrors(status: Int, code: String, expected: APIError) async {
            StubURLProtocol.reply { _ in .init(status: status, json: #"{"error":{"code":"\#(code)"}}"#) }
            await #expect(throws: expected) { try await client.respond(to: Self.challengeID, approved: true, number: 12, link: Self.link) }
        }

        @Test func pendingRequests() async throws {
            StubURLProtocol.reply { _ in .init(status: 200, json: #"{"challenges":[\#(Self.challengeJSON)]}"#) }
            let pending = try await client.pendingChallenges(for: Self.link)
            #expect(pending.map(\.challenge.id) == [Self.challengeID])
            let request = try #require(StubURLProtocol.requests.first)
            #expect(request.method == "POST")
            #expect(request.path == "/v1/mfa/push/devices/22222222-2222-2222-2222-222222222222/pending")
            #expect(request.json["device_token"] as? String == "device-credential")
            StubURLProtocol.reply { _ in .init(status: 404, json: "") }
            await #expect(throws: APIError.unsupported) { try await client.pendingChallenges(for: Self.link) }
            StubURLProtocol.reply { _ in .init(status: 401, json: #"{"error":{"code":"mfa.push_unauthorized"}}"#) }
            await #expect(throws: APIError.unauthorized) { try await client.pendingChallenges(for: Self.link) }
        }

        @Test func pushTokenUpdates() async throws {
            StubURLProtocol.reply { _ in .init(status: 204) }
            try await client.updatePushToken("beef", for: Self.link)
            let request = try #require(StubURLProtocol.requests.first)
            #expect(request.path == "/v1/mfa/push/devices/22222222-2222-2222-2222-222222222222/push-token")
            #expect(request.json["push_token"] as? String == "beef")
            #expect(request.json["user_id"] as? String == "11111111-1111-1111-1111-111111111111")
            StubURLProtocol.reply { _ in .init(status: 404) }
            await #expect(throws: APIError.unsupported) { try await client.updatePushToken("beef", for: Self.link) }
        }

        @Test func unlinking() async throws {
            StubURLProtocol.reply { _ in .init(status: 204) }
            #expect(try await client.unlink(Self.link) == .removed)
            #expect(StubURLProtocol.requests.first?.path == "/v1/mfa/push/devices/22222222-2222-2222-2222-222222222222/unlink")
            StubURLProtocol.reply { _ in .init(status: 401, json: #"{"error":{"code":"mfa.push_unauthorized"}}"#) }
            #expect(try await client.unlink(Self.link) == .alreadyRemoved)
            StubURLProtocol.reply { _ in .init(status: 503) }
            await #expect(throws: APIError.server(status: 503, code: nil)) { try await client.unlink(Self.link) }
        }

        /// A 401 without Qeet ID's own code comes from something in between — a proxy, a captive portal, a gateway — and
        /// never reads as "this iPhone isn't linked".
        @Test func aBare401IsNotARefusedCredential() async {
            StubURLProtocol.reply { _ in
                .init(status: 401, json: "<html>Sign in to the Wi-Fi</html>", headers: ["Content-Type": "text/html"])
            }
            let bare = APIError.server(status: 401, code: nil)
            await #expect(throws: bare) { try await client.pendingChallenges(for: Self.link) }
            await #expect(throws: bare) { try await client.updatePushToken("beef", for: Self.link) }
            await #expect(throws: bare) { try await client.unlink(Self.link) }
            await #expect(throws: bare) { try await client.respond(to: Self.challengeID, approved: true, number: 12, link: Self.link) }
            StubURLProtocol.reply { _ in .init(status: 401, json: #"{"error":{"code":"unauthorized"}}"#) }
            await #expect(throws: APIError.server(status: 401, code: "unauthorized")) { try await client.pendingChallenges(for: Self.link) }
        }

        @Test func transportFailures() async {
            StubURLProtocol.reply { _ in .init(status: 0, error: URLError(.notConnectedToInternet)) }
            await #expect(throws: APIError.offline) { try await client.challenge(Self.challengeID) }
            StubURLProtocol.reply { _ in .init(status: 0, error: URLError(.timedOut)) }
            await #expect(throws: APIError.unreachable) { try await client.challenge(Self.challengeID) }
            StubURLProtocol.reply { _ in .init(status: 200, json: "not json") }
            await #expect(throws: APIError.invalidResponse) { try await client.challenge(Self.challengeID) }
        }

        @Test func routesAreLoggedWithoutIDs() {
            #expect(
                APIClient.route("v1/mfa/push/challenges/33333333-3333-3333-3333-333333333333/respond")
                    == "v1/mfa/push/challenges/{id}/respond")
        }
    }
}
