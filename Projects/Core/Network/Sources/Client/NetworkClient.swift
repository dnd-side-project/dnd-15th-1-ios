import Foundation

public protocol NetworkClient: Sendable {
    func request<T: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> T
    func request(_ endpoint: some APIEndpoint) async throws
}
