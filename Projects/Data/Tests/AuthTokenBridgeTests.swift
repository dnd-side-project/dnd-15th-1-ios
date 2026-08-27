import CoreNetwork
import CoreSocialAuth
import Domain
import XCTest

@testable import Data

final class AuthTokenBridgeTests: XCTestCase {
    func test_refresh_브리지가_로컬_세션을_회전하면_리포지토리도_같은_세션을_본다() async throws {
        let plainNetwork = StubNetworkClient(name: "plain")
        plainNetwork.responses[AuthStubFixture.reissuePath] = AuthTokenDTO(
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
                userID: "42",
                isOnboardingCompleted: true
            )
        )

        let bridge = AuthTokenBridge(
            authLocal: local,
            plainRemote: AuthRemoteDataSource(
                plainClient: plainNetwork,
                authedClient: plainNetwork
            )
        )

        try await bridge.refresh()

        let authedNetwork = StubNetworkClient(name: "authed")
        authedNetwork.responses[AuthStubFixture.memberKey] = AuthStubFixture.member(
            onboardingCompleted: true
        )
        let repository = AuthRepository.stub(
            plainClient: StubNetworkClient(name: "unused-plain"),
            authedClient: authedNetwork,
            authLocal: local
        )

        let restored = try await repository.restoreSession()
        XCTAssertEqual(restored?.session.accessToken, "bridge-access")
        XCTAssertEqual(restored?.session.refreshToken, "bridge-refresh")
        XCTAssertEqual(restored?.session.userID, "42")
        XCTAssertEqual(restored?.isOnboardingCompleted, true)
        XCTAssertEqual(plainNetwork.requestedPaths, [AuthStubFixture.reissuePath])
    }

    func test_refresh_회전_후에도_저장된_온보딩_플래그가_남는다() async throws {
        let plainNetwork = StubNetworkClient(name: "plain")
        plainNetwork.responses[AuthStubFixture.reissuePath] = AuthTokenDTO(
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
                userID: "42",
                isOnboardingCompleted: false
            )
        )

        let bridge = AuthTokenBridge(
            authLocal: local,
            plainRemote: AuthRemoteDataSource(
                plainClient: plainNetwork,
                authedClient: plainNetwork
            )
        )

        try await bridge.refresh()

        let rotated = try await local.loadSession()
        XCTAssertEqual(rotated?.accessToken, "bridge-access")
        XCTAssertEqual(rotated?.isOnboardingCompleted, false)
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
