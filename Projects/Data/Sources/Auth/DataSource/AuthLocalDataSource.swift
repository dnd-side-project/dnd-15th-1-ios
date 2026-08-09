import CoreStorage
import Foundation

public struct AuthLocalDataSource: Sendable {
    private let storage: any KeychainStorage
    private let key = "auth-session"

    public init(storage: any KeychainStorage) {
        self.storage = storage
    }

    func loadSession() async throws -> AuthSessionDTO? {
        try await storage.get(forKey: key)
    }

    func saveSession(_ session: AuthSessionDTO) async throws {
        try await storage.save(session, forKey: key)
    }

    func deleteSession() async throws {
        try await storage.delete(forKey: key)
    }
}
