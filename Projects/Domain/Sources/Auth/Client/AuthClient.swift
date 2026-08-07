import Foundation
import ThirdParty

@DependencyClient
public struct AuthClient: Sendable {
    public var restoreSession: @Sendable () async throws -> AuthSession?
    public var login: @Sendable (AuthProvider) async throws -> AuthSession
    public var logout: @Sendable () async throws -> Void
    public var currentSession: @Sendable () async throws -> AuthSession?
}

extension AuthClient: TestDependencyKey {
    public static let testValue = AuthClient()
}

public extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
