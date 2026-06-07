import Foundation

/// A `URLProtocol` that lets tests stub HTTP responses without touching the network.
///
/// Usage: build a session with `URLSession.mocked()`, set `requestHandler` to map a request to the
/// response it should receive, run the code under test, then inspect `capturedRequests`. Always
/// `reset()` in `tearDown` so state doesn't leak between tests.
final class MockURLProtocol: URLProtocol {
    /// Maps an outgoing request to the (response, body) it should receive, or throws to simulate a
    /// transport failure.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Every request that passed through, in order — for asserting URLs, query items, and headers.
    static var capturedRequests: [URLRequest] = []

    static func reset() {
        requestHandler = nil
        capturedRequests = []
    }

    // Required overrides of URLProtocol class methods, so they must stay `class func` (not static).
    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }

    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.capturedRequests.append(request)
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLSession {
    /// A session whose only protocol is `MockURLProtocol`.
    static func mocked() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
