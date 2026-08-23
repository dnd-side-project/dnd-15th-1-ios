import CoreStorage
import Foundation

/// `deviceId` 는 서버가 발급하지 않는다. 앱이 만들어 Keychain 에 유지한다.
/// 세션 키(`auth-session`)와 다른 키라 로그아웃해도 남는다.
public struct PushLocalDataSource: Sendable {
    private let storage: any KeychainStorage
    private let key = "push-device-id"

    public init(storage: any KeychainStorage) {
        self.storage = storage
    }

    func deviceID() async throws -> String {
        if let stored: String = try await storage.get(forKey: key) {
            return stored
        }
        let generated = UUID().uuidString
        try await storage.save(generated, forKey: key)
        return generated
    }
}
