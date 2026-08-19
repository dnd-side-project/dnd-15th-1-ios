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

    /// 온보딩 플래그만 바꾼다. 토큰은 저장된 최신 값을 그대로 둔다.
    func updateOnboardingCompleted(_ value: Bool) async throws {
        guard let current = try await loadSession() else { return }
        try await saveSession(current.with(isOnboardingCompleted: value))
    }

    func deleteSession() async throws {
        try await storage.delete(forKey: key)
    }
}
