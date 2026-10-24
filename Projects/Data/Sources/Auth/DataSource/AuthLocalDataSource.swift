import CoreStorage
import Foundation

/// 세션 키체인 입출력. 제품 코드에서는 세션 주인(`AuthSessionStore`)만 부른다.
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
