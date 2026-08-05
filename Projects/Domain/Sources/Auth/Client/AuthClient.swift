import Foundation
import ThirdParty

@DependencyClient
public struct AuthClient: Sendable {
    public var currentUser: @Sendable () async throws -> AuthUser?
    public var signIn: @Sendable () async throws -> AuthUser
    public var signOut: @Sendable () async throws -> Void
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
