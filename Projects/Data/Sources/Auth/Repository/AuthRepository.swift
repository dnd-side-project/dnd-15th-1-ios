import CoreStorage
import Domain
import Foundation

public struct AuthRepository: Sendable {
    private let authRemote: AuthRemoteDataSource
    private let authLocal: AuthLocalDataSource
    private let socialAuth: SocialAuthCredentialProvider

    public init(
        authRemote: AuthRemoteDataSource,
        authLocal: AuthLocalDataSource,
        socialAuth: SocialAuthCredentialProvider
    ) {
        self.authRemote = authRemote
        self.authLocal = authLocal
        self.socialAuth = socialAuth
    }

    public func restoreSession() async throws -> AuthBootstrap? {
        do {
            guard let session = try await authLocal.loadSession() else {
                return nil
            }
            let domainSession = AuthDTOMapper.toDomain(session)
            // Temporary: real onboarding flag arrives in a later Cycle.
            return AuthBootstrap(
                session: domainSession,
                isOnboardingCompleted: true
            )
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    public func currentSession() async throws -> AuthSession? {
        do {
            guard let session = try await authLocal.loadSession() else {
                return nil
            }
            return AuthDTOMapper.toDomain(session)
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    public func login(provider: AuthProvider) async throws -> AuthBootstrap {
        do {
            let nonce = try await authRemote.issueNonce(provider: provider)
            let credential = try await socialAuth.login(provider: provider, nonce: nonce.nonce)
            let response = try await authRemote.socialLogin(
                provider: provider,
                idToken: credential.idToken,
                authorizationCode: credential.authorizationCode,
                nonce: nonce.nonce
            )
            let session = AuthDTOMapper.toSessionDTO(response)
            try await authLocal.saveSession(session)
            let domainSession = AuthDTOMapper.toDomain(session)
            // Temporary: real onboarding flag arrives in a later Cycle.
            return AuthBootstrap(
                session: domainSession,
                isOnboardingCompleted: true
            )
        } catch {
            throw AuthErrorMapper.map(error, isLoginPath: true)
        }
    }

    public func logout() async throws {
        do {
            if let session = try await authLocal.loadSession() {
                try? await authRemote.logout(refreshToken: session.refreshToken)
            }
            try await authLocal.deleteSession()
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    public func refreshSession() async throws -> AuthSession {
        do {
            guard let current = try await authLocal.loadSession() else {
                throw AuthError.unauthorized
            }

            let refreshed = try await authRemote.reissue(refreshToken: current.refreshToken)
            let rotated = AuthDTOMapper.toSessionDTO(token: refreshed, userID: current.userID)
            try await authLocal.saveSession(rotated)
            return AuthDTOMapper.toDomain(rotated)
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }
}
