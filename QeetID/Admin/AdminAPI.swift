import Foundation

/// How an administration call went.
enum AdminResult<Value: Sendable>: Sendable {
    case ok(Value)
    /// The session is gone (signed out, timed out or revoked): sign in again.
    case signedOut
    /// The action needs a fresh passkey check first (403 step_up_required).
    case stepUpRequired
    /// The person may not do this in this organisation.
    case forbidden
    case notFound
    /// It changed meanwhile: already decided, no longer suspended.
    case conflict(String?)
    case network
    case refused(String?)

    func map<New: Sendable>(_ transform: (Value) -> New) -> AdminResult<New> {
        then { .ok(transform($0)) }
    }

    /// The next call, when this one went through.
    func then<New: Sendable>(_ next: (Value) -> AdminResult<New>) -> AdminResult<New> {
        switch self {
        case .ok(let value): next(value)
        case .signedOut: .signedOut
        case .stepUpRequired: .stepUpRequired
        case .forbidden: .forbidden
        case .notFound: .notFound
        case .conflict(let code): .conflict(code)
        case .network: .network
        case .refused(let code): .refused(code)
        }
    }

    var value: Value? {
        if case .ok(let value) = self { return value }
        return nil
    }

    var isSignedOut: Bool {
        if case .signedOut = self { return true }
        return false
    }

    /// Why it didn't go through, in words.
    var problem: String {
        switch self {
        case .network: String(localized: "Couldn’t reach Qeet ID. Check your connection and try again.")
        case .forbidden: String(localized: "Your role doesn’t allow this in this organisation.")
        case .notFound: String(localized: "It’s no longer there.")
        case .conflict: String(localized: "It changed meanwhile. Look again.")
        case .stepUpRequired: String(localized: "Qeet ID needs your passkey again first. Try again.")
        default: String(localized: "Qeet ID didn’t accept it. Try again.")
        }
    }
}

/// A session's token pair. Never reaches a screen.
struct TokenPair: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}

/// A WebAuthn ceremony the server began: its id and the request options for the passkey prompt, as JSON.
struct Ceremony: Sendable {
    let sessionId: String
    let publicKey: Data
}

struct AdminMe: Decodable, Sendable {
    var email: String = ""
}

/// An organisation the person belongs to, with their roles in it (none: a member only).
struct Organization: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    var roles: [String] = []

    private enum CodingKeys: String, CodingKey { case id, name, roles }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        roles = try c.decodeIfPresent([String].self, forKey: .roles) ?? []
    }
}

/// An access request: who asks for which role, why, and for how long (no duration: until it's taken away).
struct AccessRequest: Decodable, Identifiable, Sendable {
    struct Person: Decodable, Sendable {
        let id: String
        let email: String
        var name: String?
        var shown: String { name.flatMap { $0.isEmpty ? nil : $0 } ?? email }
    }

    struct Role: Decodable, Sendable {
        let id: String
        let name: String
        var description: String?
    }

    let id: String
    let requester: Person
    let role: Role
    var reason: String?
    var durationHours: Int?
    let status: String
    let createdAt: Date
    var accessEndsAt: Date?

    var isPending: Bool { status == "pending" }
}

struct AccessRequestPage: Decodable, Sendable {
    var accessRequests: [AccessRequest] = []
    var pending: Int = 0
}

private struct AccessRequestOne: Decodable {
    let accessRequest: AccessRequest
}

/// A critical audit event or anomaly alert, high or medium.
struct CriticalEvent: Decodable, Identifiable, Sendable {
    let id: String
    var source: String?
    let level: String
    var action: String?
    var actorUserId: String?
    var actorEmail: String?
    var resourceType: String?
    var resourceId: String?
    var ip: String?
    var reasons: [String]?
    let occurredAt: Date

    var isHigh: Bool { level == "high" }
    var isAnomaly: Bool { source == "anomaly" }
    /// The person the event is about: the one acted on, else the one who acted.
    var personId: String? { resourceType == "user" ? resourceId : actorUserId }
}

struct CriticalEventPage: Decodable, Sendable {
    var events: [CriticalEvent] = []
    var high: Int = 0
}

/// A person in the organisation, as the suspend screens need them.
struct Member: Decodable, Identifiable, Sendable {
    let id: String
    var email: String = ""
    var displayName: String?
    var status: String = "active"

    var name: String { displayName.flatMap { $0.isEmpty ? nil : $0 } ?? email }
    var isSuspended: Bool { status == "suspended" }

    private enum CodingKeys: String, CodingKey { case id, email, displayName, status }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "active"
    }
}

/// Why a person was suspended: the reasons Qeet ID records for a suspension.
enum SuspendReason: String, CaseIterable, Sendable, Hashable {
    case suspiciousActivity = "suspicious_activity"
    case accountCompromise = "account_compromise"
    case policyViolation = "policy_violation"
    case offboarding
    case other

    var label: String {
        switch self {
        case .suspiciousActivity: String(localized: "Suspicious activity")
        case .accountCompromise: String(localized: "Account may be compromised")
        case .policyViolation: String(localized: "Breaks a policy")
        case .offboarding: String(localized: "Leaving the organisation")
        case .other: String(localized: "Something else")
        }
    }
}

/// The Qeet ID routes the administration screens call, with the administrator's own session: the token form of
/// passkey sign-in, renewal and switching organisation, the passkey step-up, access requests, critical events,
/// suspending a person and the AI agent kill switch. The bearer token is passed in for each call; nothing here keeps
/// or logs it, or a body.
struct AdminAPI: Sendable {
    var baseURL: URL = APIEnvironment.baseURL
    var session: URLSession = .shared

    // Signing in

    func beginSignIn() async -> AdminResult<Ceremony> { await ceremony(post("passkeys/login/begin", nil, body: Data())) }

    func finishSignIn(ceremony: String, credential: Data) async -> AdminResult<TokenPair> {
        await call(post("passkeys/login/finish", nil, body: Self.ceremonyBody(ceremony, credential)), TokenPair.self)
    }

    func refresh(_ refreshToken: String) async -> AdminResult<TokenPair> {
        await call(post("auth/refresh", nil, json: ["refresh_token": refreshToken]), TokenPair.self)
    }

    func switchOrganization(_ access: String, to tenant: String) async -> AdminResult<TokenPair> {
        await call(post("auth/switch-tenant", access, json: ["tenant_id": tenant]), TokenPair.self)
    }

    func signOut(_ access: String) async { _ = await send(request("auth/session", access, method: "DELETE")) }

    func me(_ access: String) async -> AdminResult<AdminMe> { await call(request("me", access), AdminMe.self) }

    func organizations(_ access: String) async -> AdminResult<[Organization]> {
        struct Page: Decodable { var items: [Organization] = [] }
        return await call(request("me/organizations", access), Page.self).map(\.items)
    }

    /// A passkey check for this session, which the server counts as a step-up for a few minutes.
    func beginStepUp(_ access: String) async -> AdminResult<Ceremony> {
        await ceremony(post("mfa/webauthn/challenge", access, json: [:]))
    }

    func finishStepUp(_ access: String, ceremony: String, credential: Data) async -> AdminResult<Void> {
        await call(post("mfa/webauthn/verify", access, body: Self.ceremonyBody(ceremony, credential)))
    }

    // Access requests

    func accessRequests(_ access: String, tenant: String) async -> AdminResult<AccessRequestPage> {
        await call(
            request("tenants/\(tenant)/access-requests", access, query: [URLQueryItem(name: "status", value: "pending")]),
            AccessRequestPage.self)
    }

    func accessRequest(_ access: String, tenant: String, id: String) async -> AdminResult<AccessRequest> {
        await call(request("tenants/\(tenant)/access-requests/\(id)", access), AccessRequestOne.self).map(\.accessRequest)
    }

    func approve(_ access: String, tenant: String, id: String, note: String) async -> AdminResult<AccessRequest> {
        await call(post("tenants/\(tenant)/access-requests/\(id)/approve", access, json: ["note": note]), AccessRequestOne.self).map(
            \.accessRequest)
    }

    func deny(_ access: String, tenant: String, id: String, note: String) async -> AdminResult<AccessRequest> {
        await call(post("tenants/\(tenant)/access-requests/\(id)/deny", access, json: ["note": note]), AccessRequestOne.self).map(
            \.accessRequest)
    }

    // Critical events

    func criticalEvents(_ access: String, tenant: String) async -> AdminResult<CriticalEventPage> {
        await call(request("tenants/\(tenant)/critical-events", access), CriticalEventPage.self)
    }

    // People

    func members(_ access: String, query: String) async -> AdminResult<[Member]> {
        struct Page: Decodable { var items: [Member] = [] }
        var items = [URLQueryItem(name: "limit", value: "25"), URLQueryItem(name: "sort", value: "name")]
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { items.append(URLQueryItem(name: "q", value: trimmed)) }
        return await call(request("users", access, query: items), Page.self).map(\.items)
    }

    func member(_ access: String, id: String) async -> AdminResult<Member> { await call(request("users/\(id)", access), Member.self) }

    /// Suspends `id`: signed out everywhere, and no sign-in until reactivated.
    func suspend(_ access: String, id: String) async -> AdminResult<Void> {
        await call(request("users/\(id)", access, method: "PATCH", json: ["status": "suspended"]))
    }

    /// Records why `id` was suspended, for whoever reviews it.
    func recordSuspension(_ access: String, id: String, reason: SuspendReason) async -> AdminResult<Void> {
        await call(
            request(
                "users/\(id)/suspension", access, method: "PUT", json: ["reason": reason.rawValue, "risk": "high", "review": "pending"]))
    }

    func reactivate(_ access: String, id: String) async -> AdminResult<Void> {
        await call(post("users/\(id)/reactivate", access, json: [:]))
    }

    // AI agents

    /// How many of the organisation's agents can act now.
    func runningAgents(_ access: String, tenant: String) async -> AdminResult<Int> {
        struct Agent: Decodable { var disabled: Bool? }
        struct Page: Decodable { var items: [Agent] = [] }
        return await call(request("tenants/\(tenant)/agents", access), Page.self).map { $0.items.filter { $0.disabled != true }.count }
    }

    func stopAllAgents(_ access: String, tenant: String) async -> AdminResult<Int> {
        struct Stopped: Decodable { var suspended: Int = 0 }
        return await call(post("tenants/\(tenant)/agents/kill-all", access, json: [:]), Stopped.self).map(\.suspended)
    }

    // Plumbing

    private func request(
        _ path: String, _ access: String?, method: String = "GET", query: [URLQueryItem] = [], json: [String: String]? = nil,
        body: Data? = nil
    ) -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: "v1/" + path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("QeetID-iOS/\(AppIdentity.version) (\(AppIdentity.build))", forHTTPHeaderField: "User-Agent")
        if let access { request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization") }
        if let json {
            request.httpBody = try? JSONSerialization.data(withJSONObject: json)
        } else if let body {
            request.httpBody = body
        }
        if request.httpBody != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return request
    }

    private func post(_ path: String, _ access: String?, json: [String: String]) -> URLRequest {
        request(path, access, method: "POST", json: json)
    }

    private func post(_ path: String, _ access: String?, body: Data) -> URLRequest {
        request(path, access, method: "POST", body: body)
    }

    /// `{"session_id": …, "credential": <the passkey's JSON, as JSON>}`.
    private static func ceremonyBody(_ ceremony: String, _ credential: Data) -> Data {
        let parsed = (try? JSONSerialization.jsonObject(with: credential)) ?? [:]
        return (try? JSONSerialization.data(withJSONObject: ["session_id": ceremony, "credential": parsed])) ?? Data()
    }

    private func ceremony(_ request: URLRequest) async -> AdminResult<Ceremony> {
        await send(request).then { data in
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let id = object["session_id"] as? String, let options = object["publicKey"],
                let json = try? JSONSerialization.data(withJSONObject: options)
            else { return .refused(nil) }
            return .ok(Ceremony(sessionId: id, publicKey: json))
        }
    }

    private func call(_ request: URLRequest) async -> AdminResult<Void> { await send(request).map { _ in () } }

    private func call<T: Decodable & Sendable>(_ request: URLRequest, _ type: T.Type) async -> AdminResult<T> {
        await send(request).then { data in
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = ServerDate.decoding
            guard let value = try? decoder.decode(T.self, from: data) else { return .refused(nil) }
            return .ok(value)
        }
    }

    private func send(_ request: URLRequest) async -> AdminResult<Data> {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .network
        }
        guard let http = response as? HTTPURLResponse else { return .network }
        if (200..<300).contains(http.statusCode) { return .ok(data) }
        let code = (try? JSONDecoder().decode(ServerErrorEnvelope.self, from: data))?.error?.code
        switch http.statusCode {
        case 401: return .signedOut
        case 403 where code == "step_up_required": return .stepUpRequired
        case 403: return .forbidden
        case 404: return .notFound
        case 409: return .conflict(code)
        default: return .refused(code)
        }
    }
}
