import Foundation
import ThirdPartyCore

final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    struct StubResponse: Sendable {
        let statusCode: Int
        let headers: [String: String]
        let data: Data
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _requestHandler:
        (@Sendable (URLRequest) throws -> StubResponse)?
    nonisolated(unsafe) private static var _requests: [URLRequest] = []

    static var requestHandler: (@Sendable (URLRequest) throws -> StubResponse)? {
        get { lock.withLock { _requestHandler } }
        set { lock.withLock { _requestHandler = newValue } }
    }

    static var requests: [URLRequest] {
        lock.withLock { _requests }
    }

    static func reset() {
        lock.withLock {
            _requestHandler = nil
            _requests.removeAll()
        }
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let observedRequest = Self.materializedRequest(from: request)
        Self.lock.withLock { Self._requests.append(observedRequest) }

        do {
            guard let handler = Self.requestHandler else {
                throw NSError(domain: "URLProtocolStub", code: 1)
            }
            let stub = try handler(observedRequest)
            guard let url = observedRequest.url else {
                throw NSError(domain: "URLProtocolStub", code: 2)
            }
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
            ) else {
                throw NSError(domain: "URLProtocolStub", code: 3)
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func materializedRequest(from request: URLRequest) -> URLRequest {
        var copy = request
        if copy.httpBody == nil, let stream = copy.httpBodyStream {
            stream.open()
            defer { stream.close() }

            let bufferSize = 1024
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }

            while stream.hasBytesAvailable {
                let readCount = stream.read(buffer, maxLength: bufferSize)
                if readCount > 0 {
                    data.append(buffer, count: readCount)
                } else {
                    break
                }
            }
            copy.httpBody = data
        }
        return copy
    }
}

enum TestSessionFactory {
    static func make(interceptor: RequestInterceptor? = nil) -> Session {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return Session(configuration: config, interceptor: interceptor)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
