import CoreNetwork
import Foundation

/// 경로마다 정해 둔 응답을 차례로 돌려준다. 마지막 응답은 그 뒤로도 계속 쓴다.
/// 붙잡아 둔 경로의 요청은 `release(_:)` 를 부를 때까지 끝나지 않는다.
actor ScriptedNetworkClient: NetworkClient {
    enum Reply: Sendable {
        case value(any Sendable)
        case empty
        case failure(NetworkError)
    }

    private var replies: [String: [Reply]] = [:]
    private var heldPaths: Set<String> = []
    private var heldRequests: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var arrivalHandlers: [String: @Sendable () -> Void] = [:]
    private var sent: [(path: String, body: Data?)] = []

    func reply(_ reply: Reply, to path: String) {
        replies[path, default: []].append(reply)
    }

    func hold(_ path: String) {
        heldPaths.insert(path)
    }

    func release(_ path: String) {
        heldPaths.remove(path)
        let held = heldRequests.removeValue(forKey: path) ?? []
        for continuation in held {
            continuation.resume()
        }
    }

    /// 그 경로로 요청이 닿을 때마다 부른다. 붙잡기 전에 부르므로 "요청이 닿았다" 는 신호로 쓴다
    func onArrival(of path: String, _ handler: @escaping @Sendable () -> Void) {
        arrivalHandlers[path] = handler
    }

    func count(of path: String) -> Int {
        sent.filter { $0.path == path }.count
    }

    func bodies(of path: String) -> [Data?] {
        sent.filter { $0.path == path }.map(\.body)
    }

    func request<T: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> T {
        switch await nextReply(for: endpoint) {
        case let .value(value):
            guard let typed = value as? T else {
                throw NetworkError.invalidResponse
            }
            return typed
        case .empty:
            throw NetworkError.invalidResponse
        case let .failure(error):
            throw error
        }
    }

    func request(_ endpoint: some APIEndpoint) async throws {
        if case let .failure(error) = await nextReply(for: endpoint) {
            throw error
        }
    }

    private func nextReply(for endpoint: some APIEndpoint) async -> Reply {
        let path = endpoint.path
        sent.append((path: path, body: endpoint.body))
        arrivalHandlers[path]?()
        if heldPaths.contains(path) {
            await withCheckedContinuation { heldRequests[path, default: []].append($0) }
        }
        guard var queue = replies[path], let first = queue.first else {
            return .failure(.notFound(message: "정해 둔 응답이 없다: \(path)"))
        }
        if queue.count > 1 {
            queue.removeFirst()
            replies[path] = queue
        }
        return first
    }
}
