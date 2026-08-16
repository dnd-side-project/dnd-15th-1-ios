import CoreNetwork
import Domain
import Foundation

final class AuthTokenBridge: TokenProviding, TokenRefreshing, @unchecked Sendable {
    private let authLocal: AuthLocalDataSource
    private let plainRemote: AuthRemoteDataSource

    init(
        authLocal: AuthLocalDataSource,
        plainRemote: AuthRemoteDataSource
    ) {
        self.authLocal = authLocal
        self.plainRemote = plainRemote
    }

    func accessToken() async throws -> String? {
        try await authLocal.loadSession()?.accessToken
    }

    func refresh() async throws {
        guard let current = try await authLocal.loadSession() else {
            throw AuthError.unauthorized
        }

        let refreshed = try await plainRemote.reissue(refreshToken: current.refreshToken)
        let rotated = AuthDTOMapper.toSessionDTO(token: refreshed, rotating: current)
        try await authLocal.saveSession(rotated)
    }
}
