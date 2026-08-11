import CoreNetwork
import CoreSocialAuth
import Domain
import XCTest

@testable import Data

final class AuthTokenBridgeTests: XCTestCase {
    func test_refresh_브리지가_로컬_세션을_회전하면_리포지토리도_같은_세션을_본다() async throws {
        let plainNetwork = StubNetworkClient(name: "plain")
        plainNetwork.responses["/api/v1/auth/reissue"] = AuthTokenDTO(
            tokenType: "Bearer",
            accessToken: "bridge-access",
            refreshToken: "bridge-refresh",
            expiresIn: 900
        )

        let keychain = StubKeychainStorage()
        let local = AuthLocalDataSource(storage: keychain)
        try await local.saveSession(
            AuthSessionDTO(
                accessToken: "old-access",
                refreshToken: "old-refresh",
                userID: "42"
            )
        )

        let plainRemote = AuthRemoteDataSource(
            plainClient: plainNetwork,
            authedClient: plainNetwork
        )
        let bridge = AuthTokenBridge(
            authLocal: local,
            plainRemote: plainRemote
        )

        try await bridge.refresh()

        let repository = AuthRepository(
            authRemote: AuthRemoteDataSource(
                plainClient: StubNetworkClient(name: "unused-plain"),
                authedClient: StubNetworkClient(name: "unused-authed")
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

        let restored = try await repository.restoreSession()
        XCTAssertEqual(restored?.session.accessToken, "bridge-access")
        XCTAssertEqual(restored?.session.refreshToken, "bridge-refresh")
        XCTAssertEqual(restored?.session.userID, "42")
        XCTAssertEqual(restored?.isOnboardingCompleted, true)
        XCTAssertEqual(plainNetwork.requestedPaths, ["/api/v1/auth/reissue"])
    }

    func test_accessToken_로컬_세션에서_토큰을_읽는다() async throws {
        let keychain = StubKeychainStorage()
        let local = AuthLocalDataSource(storage: keychain)
        try await local.saveSession(
            AuthSessionDTO(
                accessToken: "stored-access",
                refreshToken: "stored-refresh",
                userID: "1"
            )
        )

        let bridge = AuthTokenBridge(
            authLocal: local,
            plainRemote: AuthRemoteDataSource(
                plainClient: StubNetworkClient(name: "plain"),
                authedClient: StubNetworkClient(name: "authed")
            )
        )

        let accessToken = try await bridge.accessToken()
        XCTAssertEqual(accessToken, "stored-access")
    }
}
