import CoreNetwork
import CoreSocialAuth
import Domain
import XCTest

@testable import Data

final class AuthRepositoryTests: XCTestCase {
    func test_login_성공_경로에서_세션을_저장한다() async throws {
        let network = StubNetworkClient()
        network.responses[AuthStubFixture.noncePath] = AuthStubFixture.nonce
        network.responses[AuthStubFixture.socialLoginPath] = AuthStubFixture.socialLogin(
            onboardingCompleted: true
        )
        network.responses[AuthStubFixture.memberKey] = AuthStubFixture.member(
            onboardingCompleted: true
        )

        let local = AuthLocalDataSource(storage: StubKeychainStorage())
        let repository = AuthRepository.stub(plainClient: network, authLocal: local)

        let bootstrap = try await repository.login(provider: .kakao)

        XCTAssertEqual(bootstrap.session.userID, "42")
        XCTAssertEqual(bootstrap.session.accessToken, "access")
        XCTAssertEqual(bootstrap.session.refreshToken, "refresh")
        XCTAssertTrue(bootstrap.isOnboardingCompleted)
        XCTAssertEqual(
            network.requestedPaths,
            [AuthStubFixture.noncePath, AuthStubFixture.socialLoginPath]
        )

        let restored = try await repository.restoreSession()
        XCTAssertEqual(restored, bootstrap)
        XCTAssertEqual(restored?.session.userID, "42")
        XCTAssertEqual(restored?.isOnboardingCompleted, true)
    }

    func test_login_응답이_온보딩_미완료면_플래그가_false다() async throws {
        let (repository, local) = makeLoginRepository(onboardingCompleted: false)

        let bootstrap = try await repository.login(provider: .kakao)

        XCTAssertFalse(bootstrap.isOnboardingCompleted)
        let stored = try await local.loadSession()
        XCTAssertEqual(stored?.isOnboardingCompleted, false)
    }

    func test_login_응답이_온보딩_완료면_플래그가_true다() async throws {
        let (repository, local) = makeLoginRepository(onboardingCompleted: true)

        let bootstrap = try await repository.login(provider: .kakao)

        XCTAssertTrue(bootstrap.isOnboardingCompleted)
        let stored = try await local.loadSession()
        XCTAssertEqual(stored?.isOnboardingCompleted, true)
    }

    func test_login_응답에_온보딩_필드가_없으면_미완료로_본다() async throws {
        let (repository, local) = makeLoginRepository(onboardingCompleted: nil)

        let bootstrap = try await repository.login(provider: .kakao)

        XCTAssertFalse(bootstrap.isOnboardingCompleted)
        let stored = try await local.loadSession()
        XCTAssertNil(stored?.isOnboardingCompleted)
    }

    func test_social_login_응답에_온보딩_필드가_없어도_디코딩은_성공한다() throws {
        let json = """
        {
          "memberId": 42,
          "newMember": false,
          "token": {
            "tokenType": "Bearer",
            "accessToken": "access",
            "refreshToken": "refresh",
            "expiresIn": 900
          }
        }
        """

        let decoded = try JSONDecoder().decode(
            SocialLoginResponseDTO.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(decoded.memberId, 42)
        XCTAssertNil(decoded.onboardingCompleted)
    }

    func test_social_취소시_세션을_저장하지_않는다() async throws {
        let network = StubNetworkClient()
        network.responses[AuthStubFixture.noncePath] = AuthStubFixture.nonce

        let repository = AuthRepository.stub(
            plainClient: network,
            authLocal: AuthLocalDataSource(storage: StubKeychainStorage()),
            socialAuth: .stub(
                kakao: StubSocialAuthClient(
                    credential: .stub(),
                    error: SocialAuthError.cancelled
                )
            )
        )

        do {
            _ = try await repository.login(provider: .kakao)
            XCTFail("Expected cancelled")
        } catch let error as AuthError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let restored = try await repository.restoreSession()
        XCTAssertNil(restored)
        XCTAssertEqual(network.requestedPaths, [AuthStubFixture.noncePath])
    }

    func test_apple_authorizationCode가_social_login_요청_본문에_포함된다() async throws {
        let network = StubNetworkClient()
        network.responses[AuthStubFixture.noncePath] = AuthStubFixture.nonce
        network.responses[AuthStubFixture.socialLoginPath] = AuthStubFixture.socialLogin(
            onboardingCompleted: true
        )

        let authorizationCode = "apple-auth-code"
        let repository = AuthRepository.stub(
            plainClient: network,
            authLocal: AuthLocalDataSource(storage: StubKeychainStorage()),
            socialAuth: .stub(
                apple: StubSocialAuthClient(
                    credential: .stub(
                        idToken: "apple-id-token",
                        authorizationCode: authorizationCode
                    )
                )
            )
        )

        _ = try await repository.login(provider: .apple)

        guard let body = network.requestedBodies[AuthStubFixture.socialLoginPath] as? Data else {
            XCTFail("Expected social-login body")
            return
        }

        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["provider"] as? String, "APPLE")
        XCTAssertEqual(json?["idToken"] as? String, "apple-id-token")
        XCTAssertEqual(json?["authorizationCode"] as? String, authorizationCode)
        XCTAssertEqual(json?["nonce"] as? String, "raw-nonce")
    }

    func test_logout_원격_실패해도_로컬_세션을_지운다() async throws {
        let network = StubNetworkClient()
        network.errors[AuthStubFixture.logoutPath] = NetworkError.unauthorized

        let local = AuthLocalDataSource(storage: StubKeychainStorage())
        try await local.saveStubSession(userID: "1", isOnboardingCompleted: true)

        let repository = AuthRepository.stub(plainClient: network, authLocal: local)

        try await repository.logout()

        let restored = try await repository.restoreSession()
        XCTAssertNil(restored)
    }

    func test_refresh_토큰을_회전하고_온보딩_플래그를_유지한다() async throws {
        let network = StubNetworkClient()
        network.responses[AuthStubFixture.reissuePath] = AuthTokenDTO(
            tokenType: "Bearer",
            accessToken: "new-access",
            refreshToken: "new-refresh",
            expiresIn: 900
        )
        network.responses[AuthStubFixture.memberKey] = AuthStubFixture.member(
            onboardingCompleted: true
        )

        let local = AuthLocalDataSource(storage: StubKeychainStorage())
        try await local.saveStubSession(
            accessToken: "old-access",
            refreshToken: "old-refresh",
            userID: "7",
            isOnboardingCompleted: true
        )

        let repository = AuthRepository.stub(plainClient: network, authLocal: local)

        let refreshed = try await repository.refreshSession()
        XCTAssertEqual(refreshed.accessToken, "new-access")
        XCTAssertEqual(refreshed.refreshToken, "new-refresh")
        XCTAssertEqual(refreshed.userID, "7")

        let rotated = try await local.loadSession()
        XCTAssertEqual(rotated?.isOnboardingCompleted, true)

        let restored = try await repository.restoreSession()
        XCTAssertEqual(restored?.session, refreshed)
        XCTAssertEqual(restored?.isOnboardingCompleted, true)
    }

    func test_온보딩_플래그_저장이_재발급된_토큰을_덮지_않는다() async throws {
        let network = StubNetworkClient()
        network.responses[AuthStubFixture.memberKey] = AuthStubFixture.member(
            onboardingCompleted: true
        )

        let local = AuthLocalDataSource(storage: StubKeychainStorage())
        try await local.saveStubSession(
            accessToken: "old-access",
            refreshToken: "old-refresh",
            userID: "7",
            isOnboardingCompleted: nil
        )

        // members/me 응답 직전에 인터셉터가 토큰을 회전시킨 상황을 만든다
        network.onRequest = {
            try? await local.saveSession(
                AuthSessionDTO(
                    accessToken: "new-access",
                    refreshToken: "new-refresh",
                    userID: "7",
                    isOnboardingCompleted: nil
                )
            )
        }

        let repository = AuthRepository.stub(plainClient: network, authLocal: local)

        let bootstrap = try await repository.restoreSession()

        XCTAssertEqual(bootstrap?.isOnboardingCompleted, true)

        let stored = try await local.loadSession()
        XCTAssertEqual(stored?.accessToken, "new-access")
        XCTAssertEqual(stored?.refreshToken, "new-refresh")
        XCTAssertEqual(stored?.isOnboardingCompleted, true)
    }

    func test_logout_요청은_authed_클라이언트_경로를_사용한다() async throws {
        let plainClient = StubNetworkClient(name: "plain")
        let authedClient = StubNetworkClient(name: "authed")

        let local = AuthLocalDataSource(storage: StubKeychainStorage())
        try await local.saveStubSession(userID: "1")

        let repository = AuthRepository.stub(
            plainClient: plainClient,
            authedClient: authedClient,
            authLocal: local
        )

        try await repository.logout()

        XCTAssertEqual(plainClient.requestedPaths, [])
        XCTAssertEqual(authedClient.requestedPaths, [AuthStubFixture.logoutPath])
    }

    private func makeLoginRepository(
        onboardingCompleted: Bool?
    ) -> (AuthRepository, AuthLocalDataSource) {
        let network = StubNetworkClient()
        network.responses[AuthStubFixture.noncePath] = AuthStubFixture.nonce
        network.responses[AuthStubFixture.socialLoginPath] = AuthStubFixture.socialLogin(
            onboardingCompleted: onboardingCompleted
        )

        let local = AuthLocalDataSource(storage: StubKeychainStorage())
        return (AuthRepository.stub(plainClient: network, authLocal: local), local)
    }
}
