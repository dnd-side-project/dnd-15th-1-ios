import Domain
import Foundation

public struct AuthRemoteDatasource: Sendable {
    public init() {}

    func signIn() async throws -> AuthSessionDTO {
        AuthSessionDTO(AuthUser(id: "demo-user"))
    }
}
