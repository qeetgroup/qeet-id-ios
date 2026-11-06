import Foundation
import os

@testable import QeetID

/// Answers the app's requests in tests, and records them. Suites that use it run serialized.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Recorded: Sendable {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data
        var json: [String: Any] { (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:] }
    }

    struct Reply: Sendable {
        var status: Int
        var json: String = ""
        var headers: [String: String] = [:]
        var error: URLError?
    }

    private static let state = OSAllocatedUnfairLock<(handler: (@Sendable (Recorded) -> Reply)?, requests: [Recorded])>(
        initialState: (nil, []))

    static func reply(_ handler: @escaping @Sendable (Recorded) -> Reply) {
        state.withLock { $0 = (handler, []) }
    }

    static var requests: [Recorded] { state.withLock { $0.requests } }

    static func client() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(baseURL: URL(string: "https://api.test")!, session: URLSession(configuration: configuration))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(buffer, count: count)
            }
            stream.close()
        }
        let recorded = Recorded(
            method: request.httpMethod ?? "GET", path: request.url?.path ?? "", headers: request.allHTTPHeaderFields ?? [:], body: body)
        let handler = Self.state.withLock { state -> (@Sendable (Recorded) -> Reply)? in
            state.requests.append(recorded)
            return state.handler
        }
        let reply = handler?(recorded) ?? Reply(status: 500)
        if let error = reply.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        var headers = reply.headers
        headers["Content-Type"] = headers["Content-Type"] ?? "application/json"
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
