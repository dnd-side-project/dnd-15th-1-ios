import CoreNetwork
import CoreSocialAuth
import Domain
import XCTest

@testable import Data

final class AuthRepositoryTests: XCTestCase {
    func test_login_성공_경로에서_세션을_저장한다() async throws {
        let network = StubNetworkClient()
        network.responses["/api/v1/auth/nonce"] = AuthNonceDTO(
            nonce: "raw-nonce",
            expiresAt: "2026-08-09T00:00:00"
        )
        network.responses["/api/v1/auth/social-login"] = SocialLoginResponseDTO(
            memberId: 42,
            newMember: false,
            token: AuthTokenDTO(
                tokenType: "Bearer",
                accessToken: "access",
                refreshToken: "refresh",
                expiresIn: 900
            )
        )

        let keychain = StubKeychainStorage()
        let social = SocialAuthClients(
            kakao: StubSocialAuthClient(
                credential: SocialAuthCredential(idToken: "id-token", authorizationCode: nil)
            ),
            apple: StubSocialAuthClient(
                credential: SocialAuthCredential(idToken: "id-token", authorizationCode: nil)
            ),
            google: StubSocialAuthClient(
                credential: SocialAuthCredential(idToken: "id-token", authorizationCode: nil)
            )
        )

        let repository = AuthRepository(
            authRemote: AuthRemoteDataSource(networkClient: network),
            authLocal: AuthLocalDataSource(storage: keychain),
            socialAuth: SocialAuthCredentialProvider(clients: social)
        )

        let session = try await repository.login(provider: .kakao)

        XCTAssertEqual(session.userID, "42")
        XCTAssertEqual(session.accessToken, "access")
        XCTAssertEqual(session.refreshToken, "refresh")
        XCTAssertEqual(
            network.requestedPaths,
            ["/api/v1/auth/nonce", "/api/v1/auth/social-login"]
        )

        let restored = try await repository.restoreSession()
        XCTAssertEqual(restored, session)
    }

    func test_social_취소시_세션을_저장하지_않는다() async {
        let network = StubNetworkClient()
        network.responses["/api/v1/auth/nonce"] = AuthNonceDTO(
            nonce: "raw-nonce",
            expiresAt: "2026-08-09T00:00:00"
        )

        let keychain = StubKeychainStorage()
        let social = SocialAuthClients(
            kakao: StubSocialAuthClient(
                credential: SocialAuthCredential(idToken: "id-token", authorizationCode: nil),
                error: SocialAuthError.cancelled
            ),
            apple: StubSocialAuthClient(
                credential: SocialAuthCredential(idToken: "id-token", authorizationCode: nil)
            ),
            google: StubSocialAuthClient(
                credential: SocialAuthCredential(idToken: "id-token", authorizationCode: nil)
            )
        )

        let repository = AuthRepository(
            authRemote: AuthRemoteDataSource(networkClient: network),
            authLocal: AuthLocalDataSource(storage: keychain),
            socialAuth: SocialAuthCredentialProvider(clients: social)
        )

        do {
            _ = try await repository.login(provider: .kakao)
            XCTFail("Expected cancelled")
        } catch let error as AuthError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let restored = try? await repository.restoreSession()
        XCTAssertNil(restored)
        XCTAssertEqual(network.requestedPaths, ["/api/v1/auth/nonce"])
    }

    func test_logout_원격_실패해도_로컬_세션을_지운다() async throws {
        let network = StubNetworkClient()
        network.errors["/api/v1/auth/logout"] = NetworkError.unauthorized

        let keychain = StubKeychainStorage()
        let local = AuthLocalDataSource(storage: keychain)
        try await local.saveSession(
            AuthSessionDTO(
                accessToken: "access",
                refreshToken: "refresh",
                userID: "1"
            )
        )

        let repository = AuthRepository(
            authRemote: AuthRemoteDataSource(networkClient: network),
            authLocal: local,
            socialAuth: SocialAuthCredentialProvider(
                clients: SocialAuthClients(
                    kakao: StubSocialAuthClient(
                        credential: SocialAuthCredential(idToken: "id", authorizationCode: nil)
                    ),
                    apple: StubSocialAuthClient(
                        credential: SocialAuthCredential(idToken: "id", authorizationCode: nil)
                    ),
                    google: StubSocialAuthClient(
                        credential: SocialAuthCredential(idToken: "id", authorizationCode: nil)
                    )
                )
            )
        )

        try await repository.logout()

        let restored = try await repository.restoreSession()
        XCTAssertNil(restored)
    }

    func test_refresh_토큰을_회전한다() async throws {
        let network = StubNetworkClient()
        network.responses["/api/v1/auth/reissue"] = AuthTokenDTO(
            tokenType: "Bearer",
            accessToken: "new-access",
            refreshToken: "new-refresh",
            expiresIn: 900
        )

        let keychain = StubKeychainStorage()
        let local = AuthLocalDataSource(storage: keychain)
        try await local.saveSession(
            AuthSessionDTO(
                accessToken: "old-access",
                refreshToken: "old-refresh",
                userID: "7"
            )
        )

        let repository = AuthRepository(
            authRemote: AuthRemoteDataSource(networkClient: network),
            authLocal: local,
            socialAuth: SocialAuthCredentialProvider(
                clients: SocialAuthClients(
                    kakao: StubSocialAuthClient(
                        credential: SocialAuthCredential(idToken: "id", authorizationCode: nil)
                    ),
                    apple: StubSocialAuthClient(
                        credential: SocialAuthCredential(idToken: "id", authorizationCode: nil)
                    ),
                    google: StubSocialAuthClient(
                        credential: SocialAuthCredential(idToken: "id", authorizationCode: nil)
                    )
                )
            )
        )

        let refreshed = try await repository.refreshSession()
        XCTAssertEqual(refreshed.accessToken, "new-access")
        XCTAssertEqual(refreshed.refreshToken, "new-refresh")
        XCTAssertEqual(refreshed.userID, "7")

        let restored = try await repository.restoreSession()
        XCTAssertEqual(restored, refreshed)
    }

    func test_logout_요청은_authed_클라이언트_경로를_사용한다() async throws {
        let plainClient = StubNetworkClient(name: "plain")
        let authedClient = StubNetworkClient(name: "authed")

        let keychain = StubKeychainStorage()
        let local = AuthLocalDataSource(storage: keychain)
        try await local.saveSession(
            AuthSessionDTO(
                accessToken: "access",
                refreshToken: "refresh",
                userID: "1"
            )
        )

        let repository = AuthRepository(
            authRemote: AuthRemoteDataSource(
                plainClient: plainClient,
                authedClient: authedClient
            ),
            authLocal: local,
            socialAuth: SocialAuthCredentialProvider(
                clients: SocialAuthClients(
                    kakao: StubSocialAuthClient(
                        credential: SocialAuthCredential(idToken: "id", authorizationCode: nil)
                    ),
                    apple: StubSocialAuthClient(
                        credential: SocialAuthCredential(idToken: "id", authorizationCode: nil)
                    ),
                    google: StubSocialAuthClient(
                        credential: SocialAuthCredential(idToken: "id", authorizationCode: nil)
                    )
                )
            )
        )

        try await repository.logout()

        XCTAssertEqual(plainClient.requestedPaths, [])
        XCTAssertEqual(authedClient.requestedPaths, ["/api/v1/auth/logout"])
    }
}
