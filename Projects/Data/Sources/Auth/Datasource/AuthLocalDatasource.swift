import CoreStorage
import Foundation

public struct AuthLocalDatasource: Sendable {
    private let storage: any KeychainStorage
    private let key = "auth-session"

    public init(storage: any KeychainStorage) {
        self.storage = storage
    }

    func loadSession() async throws -> AuthSessionDTO? {
        try await storage.get(forKey: key)
    }

    func saveSession(_ session: AuthSessionDTO?) async throws {
        if let session {
            try await storage.save(session, forKey: key)
        } else {
            try await storage.delete(forKey: key)
        }
    }
}
