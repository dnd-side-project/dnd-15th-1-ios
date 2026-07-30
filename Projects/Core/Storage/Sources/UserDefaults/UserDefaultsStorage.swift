import Foundation

public protocol UserDefaultsStorage: Sendable {
    func save(_ value: some Codable & Sendable, forKey key: String) async throws
    func get<T: Codable & Sendable>(forKey key: String) async throws -> T?
    func delete(forKey key: String) async throws
    func setBool(_ value: Bool, forKey key: String) async
    func bool(forKey key: String) async -> Bool
}
