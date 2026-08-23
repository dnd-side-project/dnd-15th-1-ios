import CoreNetwork
import CoreStorage
import Domain
import Foundation

public struct AuthRepository: Sendable {
    private let authRemote: AuthRemoteDataSource
    private let authLocal: AuthLocalDataSource
    private let socialAuth: SocialAuthCredentialProvider
    private let profileRemote: ProfileRemoteDataSource
    /// 로그아웃 때 이 기기의 푸시 등록을 뗀다. 실패는 삼킨다
    private let notificationRepository: NotificationRepository?

    public init(
        authRemote: AuthRemoteDataSource,
        authLocal: AuthLocalDataSource,
        socialAuth: SocialAuthCredentialProvider,
        profileRemote: ProfileRemoteDataSource,
        notificationRepository: NotificationRepository? = nil
    ) {
        self.authRemote = authRemote
        self.authLocal = authLocal
        self.socialAuth = socialAuth
        self.profileRemote = profileRemote
        self.notificationRepository = notificationRepository
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

    /// 서버 값이 우선. 실패하면 저장된 플래그로 버티고, 그마저 없으면 미완료로 본다.
    private func resolveOnboardingCompleted(stored session: AuthSessionDTO) async throws -> Bool {
        let completed: Bool
        do {
            completed = try await profileRemote.member().onboardingCompleted
        } catch NetworkError.unauthorized {
            throw AuthError.unauthorized
        } catch {
            // 저장값이 없는 세션은 대부분 실제로 온보딩 전이다. 미완료 사용자를 메인에 넣는 것보다
            // 온보딩으로 보내는 쪽이 되돌릴 수 있고, 온라인으로 한 번 켜면 서버 값으로 교정된다.
            return session.isOnboardingCompleted ?? false
        }

        // 세션 전체를 다시 쓰면 그 사이 재발급된 토큰을 덮는다. 플래그만 갱신한다.
        try await authLocal.updateOnboardingCompleted(completed)
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
            // 서버 로그아웃이 액세스 토큰을 무효화할 수 있다. 그 전에 불러야 401 을 피한다
            try? await notificationRepository?.unregisterDevice()
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
