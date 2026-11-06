import Foundation
import Testing

@testable import QeetID

struct UserAgentDescriptionTests {
    @Test func browsersAndSystems() {
        let chromeMac =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        #expect(UserAgentDescription.describe(chromeMac) == "Chrome on macOS")
        let edgeWindows =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0"
        #expect(UserAgentDescription.describe(edgeWindows) == "Edge on Windows")
        let safariIPhone =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        #expect(UserAgentDescription.describe(safariIPhone) == "Safari on iPhone")
        #expect(
            UserAgentDescription.describe("Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0") == "Firefox on Linux")
        #expect(UserAgentDescription.describe("curl/8.7.1") == nil)
        #expect(UserAgentDescription.describe(nil) == nil)
    }
}

struct ServerDateTests {
    @Test func readsGoTimestamps() throws {
        let nano = try #require(ServerDate.parse("2026-11-06T10:47:12.123456789Z"))
        let milli = try #require(ServerDate.parse("2026-11-06T10:47:12.123Z"))
        #expect(abs(nano.timeIntervalSince(milli)) < 0.001)
        let plain = try #require(ServerDate.parse("2026-11-06T10:47:12Z"))
        #expect(milli.timeIntervalSince(plain) > 0.1)
        let offset = try #require(ServerDate.parse("2026-11-06T16:17:12.5+05:30"))
        #expect(abs(offset.timeIntervalSince(plain) - 0.5) < 0.001)
        #expect(ServerDate.parse("6 Nov 2026") == nil)
    }

    @Test func readsTheDateHeader() throws {
        let date = try #require(ServerDate.fromHTTPHeader("Fri, 06 Nov 2026 10:47:12 GMT"))
        #expect(date == ServerDate.parse("2026-11-06T10:47:12Z"))
    }
}

struct APIEnvironmentTests {
    @Test func productionIsTheDefault() {
        #expect(APIEnvironment.production.absoluteString == "https://api.id.qeet.in")
    }

    @Test func onlyPlainOriginsAreAccepted() {
        #expect(APIEnvironment.validated("http://localhost:4001")?.absoluteString == "http://localhost:4001")
        #expect(APIEnvironment.validated("https://api.id.qeet.in/")?.absoluteString == "https://api.id.qeet.in")
        #expect(APIEnvironment.validated("ftp://example.com") == nil)
        #expect(APIEnvironment.validated("https://user:pass@example.com") == nil)
        #expect(APIEnvironment.validated("https://example.com/v1") == nil)
        #expect(APIEnvironment.validated("not a url") == nil)
    }
}

struct NotificationTextTests {
    @Test func namesTheBrowserWhenItIsKnown() {
        let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0) AppleWebKit/537.36 Chrome/131 Safari/537.36"
        #expect(
            NotificationText.body(userAgent: userAgent)
                == "Someone is signing in to your Qeet ID account from Chrome on macOS. Tap to review.")
        #expect(NotificationText.body(userAgent: nil) == "Someone is signing in to your Qeet ID account. Tap to review.")
        #expect(NotificationText.title == "Sign-in request")
    }

    @Test func readsTheServersPush() {
        let payload: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "Sign-in request"], "mutable-content": 1],
            "type": "sign_in_request", "challenge_id": "2420335F-BF27-45D7-B9C3-E0972EE13C46", "action": "sign_in",
        ]
        #expect(SignInPush.challengeID(in: payload) == UUID(uuidString: "2420335F-BF27-45D7-B9C3-E0972EE13C46"))
        #expect(SignInPush.challengeID(in: ["type": "marketing", "challenge_id": "2420335F-BF27-45D7-B9C3-E0972EE13C46"]) == nil)
        #expect(SignInPush.challengeID(in: ["type": "sign_in_request", "challenge_id": "1819"]) == nil)
    }
}
