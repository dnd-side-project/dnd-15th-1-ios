import CoreNetwork
import Foundation

final class StubNetworkClient: NetworkClient, @unchecked Sendable {
    let name: String
    var responses: [String: Any] = [:]
    var errors: [String: Error] = [:]
    /// 요청이 응답을 돌려주기 직전에 끼어드는 훅. 재발급이 끼어드는 상황을 만든다.
    var onRequest: (@Sendable () async -> Void)?
    private(set) var requestedPaths: [String] = []
    private(set) var requestedKeys: [String] = []
    private(set) var requestedBodies: [String: Data?] = [:]

    init(name: String = "network") {
        self.name = name
    }

    func request<T: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> T {
        record(endpoint)
        await onRequest?()
        if let error = error(for: endpoint) {
            throw error
        }
        guard let value = response(for: endpoint) as? T else {
            throw NetworkError.invalidResponse
        }
        return value
    }

    func request(_ endpoint: some APIEndpoint) async throws {
        record(endpoint)
        await onRequest?()
        if let error = error(for: endpoint) {
            throw error
        }
    }

    private func record(_ endpoint: some APIEndpoint) {
        requestedPaths.append(endpoint.path)
        requestedKeys.append(key(for: endpoint))
        requestedBodies[key(for: endpoint)] = endpoint.body
        requestedBodies[endpoint.path] = endpoint.body
    }

    /// `"POST /path"` 를 먼저 찾고, 없으면 path 로 되돌아간다.
    /// 같은 path 를 메서드로만 구분하는 엔드포인트가 있다.
    private func response(for endpoint: some APIEndpoint) -> Any? {
        responses[key(for: endpoint)] ?? responses[endpoint.path]
    }

    private func error(for endpoint: some APIEndpoint) -> Error? {
        errors[key(for: endpoint)] ?? errors[endpoint.path]
    }

    private func key(for endpoint: some APIEndpoint) -> String {
        "\(endpoint.method.rawValue) \(endpoint.path)"
    }
}
