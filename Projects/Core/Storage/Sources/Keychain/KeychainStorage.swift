import Foundation

public protocol KeychainStorage: Sendable {
    func save(_ value: some Codable & Sendable, forKey key: String) async throws
    func get<T: Codable & Sendable>(forKey key: String) async throws -> T?
    /// 읽기와 쓰기를 한 임계 구역에서 처리한다. 저장된 값이 없으면 아무것도 하지 않는다.
    func update<T: Codable & Sendable>(
        forKey key: String,
        _ transform: @Sendable (T) -> T
    ) async throws
    func delete(forKey key: String) async throws
    func deleteAll() async throws
}
