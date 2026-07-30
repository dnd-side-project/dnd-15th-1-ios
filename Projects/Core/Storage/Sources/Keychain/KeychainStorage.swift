import Foundation

public protocol KeychainStorage: Sendable {
    func save(_ value: some Codable & Sendable, forKey key: String) async throws
    func get<T: Codable & Sendable>(forKey key: String) async throws -> T?
    func delete(forKey key: String) async throws
    func deleteAll() async throws
}
