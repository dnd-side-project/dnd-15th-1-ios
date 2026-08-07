import Domain
import Foundation

public struct AuthRemoteDatasource: Sendable {
    public init() {}

    func login(provider: AuthProvider) async throws -> AuthSessionDTO {
        _ = provider
        return AuthSessionDTO(
            accessToken: "demo-access-token",
            refreshToken: "demo-refresh-token",
            userID: "demo-user"
        )
    }
}
