import CoreNetwork
import Domain
import XCTest

@testable import Data

final class AuthRepositoryRestoreTests: XCTestCase {
    func test_restore_서버값을_쓰고_키체인_플래그를_갱신한다() async throws {
        let network = StubNetworkClient()
        network.responses[AuthStubFixture.memberKey] = AuthStubFixture.member(
            onboardingCompleted: true
        )

        let local = AuthLocalDataSource(storage: StubKeychainStorage())
        try await local.saveStubSession(isOnboardingCompleted: false)

        let repository = AuthRepository.stub(plainClient: network, authLocal: local)

        let restored = try await repository.restoreSession()

        XCTAssertEqual(restored?.isOnboardingCompleted, true)
        XCTAssertEqual(network.requestedKeys, [AuthStubFixture.memberKey])

        let stored = try await local.loadSession()
        XCTAssertEqual(stored?.isOnboardingCompleted, true)
        XCTAssertEqual(stored?.accessToken, "access")
    }

    func test_restore_전송_실패하면_저장된_플래그로_버틴다() async throws {
        let network = StubNetworkClient()
        network.errors[AuthStubFixture.memberKey] = NetworkError.transport(message: "offline")

        let local = AuthLocalDataSource(storage: StubKeychainStorage())
        try await local.saveStubSession(isOnboardingCompleted: false)

        let repository = AuthRepository.stub(plainClient: network, authLocal: local)

        let restored = try await repository.restoreSession()

        XCTAssertEqual(restored?.isOnboardingCompleted, false)
        XCTAssertEqual(restored?.session.userID, "42")
    }

    func test_restore_서버_오류에_저장된_플래그도_없으면_network를_던진다() async throws {
        let network = StubNetworkClient()
        network.errors[AuthStubFixture.memberKey] = NetworkError.serverError(
            statusCode: 500,
            message: nil
        )

        let local = AuthLocalDataSource(storage: StubKeychainStorage())
        try await local.saveStubSession()

        let repository = AuthRepository.stub(plainClient: network, authLocal: local)

        do {
            _ = try await repository.restoreSession()
            XCTFail("Expected network error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .network)
        }
    }

    func test_restore_401이면_저장값으로_버티지_않고_unauthorized를_던진다() async throws {
        let network = StubNetworkClient()
        network.errors[AuthStubFixture.memberKey] = NetworkError.unauthorized

        let local = AuthLocalDataSource(storage: StubKeychainStorage())
        try await local.saveStubSession(isOnboardingCompleted: true)

        let repository = AuthRepository.stub(plainClient: network, authLocal: local)

        do {
            _ = try await repository.restoreSession()
            XCTFail("Expected unauthorized")
        } catch let error as AuthError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    func test_restore_온보딩_키가_없는_예전_세션도_디코딩된다() async throws {
        let network = StubNetworkClient()
        network.responses[AuthStubFixture.memberKey] = AuthStubFixture.member(
            onboardingCompleted: true
        )

        let keychain = StubKeychainStorage()
        keychain.seed(
            rawJSON: """
            {
              "accessToken": "legacy-access",
              "refreshToken": "legacy-refresh",
              "userID": "9"
            }
            """,
            forKey: AuthStubFixture.sessionKey
        )

        let local = AuthLocalDataSource(storage: keychain)
        let loaded = try await local.loadSession()
        XCTAssertEqual(loaded?.accessToken, "legacy-access")
        XCTAssertNil(loaded?.isOnboardingCompleted)

        let repository = AuthRepository.stub(plainClient: network, authLocal: local)

        let restored = try await repository.restoreSession()
        XCTAssertEqual(restored?.session.accessToken, "legacy-access")
        XCTAssertEqual(restored?.isOnboardingCompleted, true)
    }
}
