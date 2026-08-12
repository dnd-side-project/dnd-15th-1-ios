import CoreNetwork
import CoreStorage
import Domain
import Foundation

public struct AuthRepository: Sendable {
    private let authRemote: AuthRemoteDataSource
    private let authLocal: AuthLocalDataSource
    private let socialAuth: SocialAuthCredentialProvider
    private let profileRemote: ProfileRemoteDataSource

    public init(
        authRemote: AuthRemoteDataSource,
        authLocal: AuthLocalDataSource,
        socialAuth: SocialAuthCredentialProvider,
        profileRemote: ProfileRemoteDataSource
    ) {
        self.authRemote = authRemote
        self.authLocal = authLocal
        self.socialAuth = socialAuth
        self.profileRemote = profileRemote
    }

    public func restoreSession() async throws -> AuthBootstrap? {
        do {
            guard let session = try await authLocal.loadSession() else {
                return nil
            }
            return AuthBootstrap(
                session: AuthDTOMapper.toDomain(session),
                isOnboardingCompleted: try await resolveOnboardingCompleted(stored: session)
            )
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }

    /// 서버 값이 우선. 실패하면 저장된 플래그로 버티고, 그마저 없으면 추측하지 않는다.
    private func resolveOnboardingCompleted(stored session: AuthSessionDTO) async throws -> Bool {
        let completed: Bool
        do {
            completed = try await profileRemote.member().onboardingCompleted
        } catch NetworkError.unauthorized {
            throw AuthError.unauthorized
        } catch {
            guard let fallback = session.isOnboardingCompleted else {
                throw AuthError.network
            }
            return fallback
        }

        try await authLocal.saveSession(session.with(isOnboardingCompleted: completed))
        return completed
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
            // 필드가 없으면 미완료로 본다. 완료한 사용자를 온보딩으로 보내는 건 닉네임 화면이
            // 다시 뜰 뿐 되돌릴 수 있지만, 미완료 사용자를 메인에 넣으면 닉네임 없이 앱이 깨진다.
            return AuthBootstrap(
                session: AuthDTOMapper.toDomain(session),
                isOnboardingCompleted: session.isOnboardingCompleted ?? false
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
            let rotated = AuthDTOMapper.toSessionDTO(token: refreshed, rotating: current)
            try await authLocal.saveSession(rotated)
            return AuthDTOMapper.toDomain(rotated)
        } catch {
            throw AuthErrorMapper.map(error)
        }
    }
}
