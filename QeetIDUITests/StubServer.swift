import Foundation
import Network
import os

/// A small HTTP server on localhost, in the UI test runner, standing in for Qeet ID's API: the app reaches it through
/// the Debug `-api-url` launch argument. Each route answers with canned JSON and every request is recorded.
final class StubServer: @unchecked Sendable {
    struct Request: Sendable {
        let method: String
        let path: String
        let body: Data
        var json: [String: Any] { (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:] }
    }

    struct Response: Sendable {
        var status: Int
        var json: String = ""
    }

    typealias Route = @Sendable (Request) -> Response

    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.qeetgroup.qeetid.uitests.stub")
    private let state = OSAllocatedUnfairLock<(routes: [String: Route], requests: [Request])>(initialState: ([:], []))

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }

    /// Starts listening and returns the base URL to pass as `-api-url`.
    func start() throws -> String {
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.serve(connection) }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 5) == .success, let port = listener.port?.rawValue else {
            throw URLError(.cannotConnectToHost)
        }
        // The address the listener is bound to. `localhost` would try ::1 first, where nothing listens.
        return "http://127.0.0.1:\(port)"
    }

    func stop() {
        listener.cancel()
    }

    /// Answers `method path` (the path may end in `*` to match a prefix).
    func route(_ method: String, _ path: String, _ handler: @escaping Route) {
        state.withLock { $0.routes["\(method) \(path)"] = handler }
    }

    var requests: [Request] { state.withLock { $0.requests } }

    func requests(_ method: String, pathSuffix: String) -> [Request] {
        requests.filter { $0.method == method && $0.path.hasSuffix(pathSuffix) }
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let request = Self.parse(buffer) {
                self.respond(to: request, on: connection)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receive(on: connection, buffer: buffer)
            }
        }
    }

    /// A whole request, once its headers and `Content-Length` bytes of body are in.
    private static func parse(_ buffer: Data) -> Request? {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)),
            let head = String(data: buffer[..<headerEnd.lowerBound], encoding: .utf8)
        else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.first?.split(separator: " ") ?? []
        guard requestLine.count >= 2 else { return nil }
        var length = 0
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                length = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        let body = buffer[headerEnd.upperBound...]
        guard body.count >= length else { return nil }
        return Request(method: String(requestLine[0]), path: String(requestLine[1]), body: Data(body.prefix(length)))
    }

    private func respond(to request: Request, on connection: NWConnection) {
        let handler = state.withLock { state -> Route? in
            state.requests.append(request)
            if let exact = state.routes["\(request.method) \(request.path)"] { return exact }
            return state.routes.first { key, _ in
                key.hasSuffix("*") && "\(request.method) \(request.path)".hasPrefix(String(key.dropLast()))
            }?.value
        }
        let response = handler?(request) ?? Response(status: 404, json: #"{"error":{"code":"not_found"}}"#)
        let body = Data(response.json.utf8)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        let head =
            "HTTP/1.1 \(response.status) Stub\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n"
            + "Date: \(formatter.string(from: Date()))\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }
}

/// Canned Qeet ID answers.
enum StubAPI {
    static let userID = "11111111-1111-1111-1111-111111111111"
    static let deviceID = "22222222-2222-2222-2222-222222222222"
    static let challengeID = "33333333-3333-3333-3333-333333333333"

    static var claim: StubServer.Response {
        .init(
            status: 201,
            json: """
                {"user_id":"\(userID)","device":{"id":"\(deviceID)","name":"Meera's iPhone","platform":"ios"},
                 "device_token":"stub-device-credential","account":{"email":"meera@brightleaffoods.in"}}
                """)
    }

    static func challenge(expiresIn seconds: TimeInterval = 120, status: String = "pending") -> String {
        let formatter = ISO8601DateFormatter()
        let now = Date()
        return """
            {"id":"\(challengeID)","user_id":"\(userID)","action":"sign_in","status":"\(status)",
             "context":{"ip":"49.205.143.27","location":"Hyderabad, India","timestamp":"\(formatter.string(from: now))",
             "user_agent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"},
             "expires_at":"\(formatter.string(from: now.addingTimeInterval(seconds)))","created_at":"\(formatter.string(from: now))"}
            """
    }

    static func pending(expiresIn seconds: TimeInterval = 120) -> StubServer.Response {
        .init(status: 200, json: #"{"challenges":[\#(challenge(expiresIn: seconds))]}"#)
    }

    static let noPending = StubServer.Response(status: 200, json: #"{"challenges":[]}"#)
}
