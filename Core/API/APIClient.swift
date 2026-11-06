import Foundation

/// The calls the app makes to Qeet ID's `/v1/mfa/push/*` routes. None carries a bearer or a session: linking uses the
/// one-time pairing code, and everything after uses the device credential **in the JSON body**.
///
/// It logs the route and the status of each call, never a body.
struct APIClient: Sendable {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL = APIEnvironment.baseURL, session: URLSession = APIClient.makeSession()) {
        self.baseURL = baseURL
        self.session = session
    }

    /// An ephemeral session: no cache, no cookies, no credential store, nothing written to disk.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    // MARK: - Linking

    /// Links this iPhone with `code` (`POST /v1/mfa/push/pairing/claim`). `pushToken` is the APNs device token in hex.
    func claimPairing(code: String, name: String, pushToken: String) async throws(APIError) -> PairingClaim {
        struct Body: Encodable {
            let code: String
            let name: String
            let pushToken: String
            let platform = "ios"

            enum CodingKeys: String, CodingKey {
                case code, name, platform
                case pushToken = "push_token"
            }
        }
        let response = try await send("POST", "v1/mfa/push/pairing/claim", body: Body(code: code, name: name, pushToken: pushToken))
        switch response.status {
        case 200, 201:
            return try decode(PairingClaim.self, from: response.data)
        case 401 where response.errorCode == "mfa.pairing_code_invalid":
            throw .pairingCodeInvalid
        case 429:
            throw .throttled(retryAfter: response.retryAfter ?? 60)
        default:
            throw response.unexpected
        }
    }

    /// Sends a new APNs token for this link (`POST /v1/mfa/push/devices/{id}/push-token`). `.unsupported` from a
    /// server that doesn't have the route yet.
    func updatePushToken(_ pushToken: String, for link: DeviceLink) async throws(APIError) {
        struct Body: Encodable {
            let userID: UUID
            let deviceToken: String
            let pushToken: String

            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case deviceToken = "device_token"
                case pushToken = "push_token"
            }
        }
        let body = Body(userID: link.userID, deviceToken: link.deviceToken, pushToken: pushToken)
        let response = try await send("POST", "v1/mfa/push/devices/\(link.deviceID.uuidString.lowercased())/push-token", body: body)
        switch response.status {
        case 200, 204: return
        case 401 where response.isDeviceCredentialRefused: throw .unauthorized
        case 404, 405: throw .unsupported
        default: throw response.unexpected
        }
    }

    /// Removes this iPhone from the account (`POST /v1/mfa/push/devices/{id}/unlink`).
    func unlink(_ link: DeviceLink) async throws(APIError) -> UnlinkOutcome {
        let response = try await send(
            "POST", "v1/mfa/push/devices/\(link.deviceID.uuidString.lowercased())/unlink", body: Credential(link))
        switch response.status {
        case 200, 204: return .removed
        case 401 where response.isDeviceCredentialRefused: return .alreadyRemoved
        default: throw response.unexpected
        }
    }

    // MARK: - Sign-in requests

    /// Reads a request (`GET /v1/mfa/push/challenges/{id}`): public, and it never reveals the number.
    func challenge(_ id: UUID) async throws(APIError) -> FetchedChallenge {
        let response = try await send("GET", "v1/mfa/push/challenges/\(id.uuidString.lowercased())", body: Optional<Credential>.none)
        switch response.status {
        case 200:
            return FetchedChallenge(
                challenge: try decode(SignInChallenge.self, from: response.data), clockOffset: response.clockOffset)
        case 400, 404, 410: throw .notFound
        default: throw response.unexpected
        }
    }

    /// The requests waiting for this iPhone, newest first (`POST /v1/mfa/push/devices/{id}/pending`). `.unsupported`
    /// from a server that doesn't have the route yet.
    func pendingChallenges(for link: DeviceLink) async throws(APIError) -> [FetchedChallenge] {
        struct Pending: Decodable {
            let challenges: [SignInChallenge]
        }
        let response = try await send(
            "POST", "v1/mfa/push/devices/\(link.deviceID.uuidString.lowercased())/pending", body: Credential(link))
        switch response.status {
        case 200:
            let pending = try decode(Pending.self, from: response.data)
            return pending.challenges.map { FetchedChallenge(challenge: $0, clockOffset: response.clockOffset) }
        case 401 where response.isDeviceCredentialRefused: throw .unauthorized
        case 404, 405: throw .unsupported
        default: throw response.unexpected
        }
    }

    /// Approves or denies a request (`POST /v1/mfa/push/challenges/{id}/respond`). An approval carries the number the
    /// person typed; the server denies it if the number is wrong (`.numberMismatch`).
    func respond(to id: UUID, approved: Bool, number: Int?, link: DeviceLink) async throws(APIError) {
        struct Body: Encodable {
            let userID: UUID
            let deviceToken: String
            let approved: Bool
            let number: Int?

            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case deviceToken = "device_token"
                case approved, number
            }
        }
        let body = Body(userID: link.userID, deviceToken: link.deviceToken, approved: approved, number: approved ? number : nil)
        let response = try await send("POST", "v1/mfa/push/challenges/\(id.uuidString.lowercased())/respond", body: body)
        switch response.status {
        case 200, 204: return
        case 403 where response.errorCode == "mfa.push_number_mismatch": throw .numberMismatch
        case 404, 410: throw .challengeExpired
        case 409: throw .challengeAnswered
        case 401 where response.isDeviceCredentialRefused: throw .unauthorized
        default: throw response.unexpected
        }
    }

    // MARK: - Transport

    /// The device credential, as the unlink and pending routes take it.
    private struct Credential: Encodable {
        let userID: UUID
        let deviceToken: String

        init(_ link: DeviceLink) {
            userID = link.userID
            deviceToken = link.deviceToken
        }

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case deviceToken = "device_token"
        }
    }

    private struct Response {
        let status: Int
        let data: Data
        let retryAfterHeader: String?
        /// The server's clock minus the phone's, from the `Date` header; 0 when there is none.
        let clockOffset: TimeInterval

        var envelope: ServerErrorEnvelope.Body? {
            (try? JSONDecoder().decode(ServerErrorEnvelope.self, from: data))?.error
        }

        var errorCode: String? { envelope?.code }

        /// Qeet ID itself refused the device credential: a 401 with its own `mfa.push_unauthorized`. A bare 401 — from a
        /// proxy, a captive portal or a gateway — is not that, and must never make the iPhone forget its link.
        var isDeviceCredentialRefused: Bool { errorCode == "mfa.push_unauthorized" }

        /// Seconds to wait, from the error's metadata or the `Retry-After` header.
        var retryAfter: Int? {
            if let seconds = envelope?.metadata?["retry_after"]?.intValue, seconds > 0 { return seconds }
            if let header = retryAfterHeader, let seconds = Int(header), seconds > 0 { return seconds }
            return nil
        }

        var unexpected: APIError {
            .server(status: status, code: errorCode)
        }
    }

    private func send<Body: Encodable>(_ method: String, _ path: String, body: Body?) async throws(APIError) -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("QeetID-iOS/\(AppIdentity.version) (\(AppIdentity.build))", forHTTPHeaderField: "User-Agent")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw .invalidResponse
            }
        }
        let sentAt = Date()
        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            let mapped = APIError(transport: error)
            Log.api.notice(
                "\(method, privacy: .public) \(Self.route(path), privacy: .public) failed: \(String(describing: mapped), privacy: .public)")
            throw mapped
        }
        guard let http = urlResponse as? HTTPURLResponse else { throw .invalidResponse }
        Log.api.info("\(method, privacy: .public) \(Self.route(path), privacy: .public) → \(http.statusCode, privacy: .public)")
        var offset: TimeInterval = 0
        if let serverNow = ServerDate.fromHTTPHeader(http.value(forHTTPHeaderField: "Date")) {
            // The midpoint of the request, against the server's second-resolution clock.
            let localNow = sentAt.addingTimeInterval(Date().timeIntervalSince(sentAt) / 2)
            offset = serverNow.timeIntervalSince(localNow)
            // A second of skew is the header's own resolution: ignore it.
            if abs(offset) < 1 { offset = 0 }
        }
        return Response(
            status: http.statusCode, data: data, retryAfterHeader: http.value(forHTTPHeaderField: "Retry-After"), clockOffset: offset)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws(APIError) -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ServerDate.decoding
        do {
            return try decoder.decode(type, from: data)
        } catch {
            Log.api.error("Couldn't read the server's answer as \(String(describing: type), privacy: .public)")
            throw .invalidResponse
        }
    }

    /// A path for the log, without ids: `v1/mfa/push/challenges/{id}/respond`.
    static func route(_ path: String) -> String {
        path.split(separator: "/").map { UUID(uuidString: String($0)) == nil ? String($0) : "{id}" }.joined(separator: "/")
    }
}

extension FetchedChallenge {
    init(challenge: SignInChallenge, clockOffset: TimeInterval) {
        self.init(challenge: challenge, expiresAtLocal: challenge.expiresAt.addingTimeInterval(-clockOffset))
    }
}
