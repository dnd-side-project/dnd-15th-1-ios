import CoreNetwork
import Domain
import Foundation
import XCTest

@testable import Data

final class ProfileRepositoryWithdrawTests: XCTestCase {
    private let withdrawKey = "DELETE /api/v1/members/me"

    func test_탈퇴에_성공하면_진행_중인_재발급이_세션을_되살리지_못한다() async throws {
        let plain = ScriptedNetworkClient()
        await plain.reply(
            AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"),
            to: AuthStubFixture.reissuePath
        )
        await plain.hold(AuthStubFixture.reissuePath)
        let reissueStarted = XCTestExpectation(description: "재발급 요청이 닿는다")
        await plain.onArrival(of: AuthStubFixture.reissuePath) { reissueStarted.fulfill() }
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            keychain: keychain,
            server: plain
        )
        let authed = StubNetworkClient(name: "authed")
        let repository = ProfileRepository(
            profileRemote: ProfileRemoteDataSource(networkClient: authed),
            sessionStore: store
        )

        let waiter = Task { await store.recover(afterUnauthorized: "A1") }
        await fulfillment(of: [reissueStarted], timeout: AuthSessionStoreFixture.signalTimeout)
        try await repository.withdraw()
        await plain.release(AuthStubFixture.reissuePath)
        let outcome = await waiter.value

        XCTAssertEqual(outcome, .fail)
        let inMemory = try await store.currentSession()
        XCTAssertNil(inMemory)
        let stored = try await AuthSessionStoreFixture.storedSession(in: keychain)
        XCTAssertNil(stored)
        // 푸시 해제와 서버 로그아웃은 보내지 않는다
        XCTAssertEqual(authed.requestedKeys, [withdrawKey])
    }

    func test_탈퇴가_실패하면_세션을_지우지_않는다() async throws {
        let authed = StubNetworkClient(name: "authed")
        authed.errors[withdrawKey] = NetworkError.serverError(statusCode: 500, message: nil)
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            server: ScriptedNetworkClient()
        )
        let repository = ProfileRepository(
            profileRemote: ProfileRemoteDataSource(networkClient: authed),
            sessionStore: store
        )

        await assertThrows(ProfileError.unknown) {
            try await repository.withdraw()
        }

        let inMemory = try await store.currentSession()
        XCTAssertEqual(inMemory?.accessToken, "A1")
    }
}
