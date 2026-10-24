import CoreNetwork
import CoreStorage
import Foundation
import XCTest

@testable import Data

final class AuthSessionStoreLogoutTests: XCTestCase {
    private let reissuePath = AuthStubFixture.reissuePath

    func test_로그아웃은_진행_중인_재발급을_기다린_뒤_새_리프레시_토큰으로_보내고_세션을_지운다() async throws {
        let server = ScriptedNetworkClient()
        await server.reply(AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"), to: reissuePath)
        await server.hold(reissuePath)
        let reissueStarted = XCTestExpectation(description: "재발급 요청이 닿는다")
        await server.onArrival(of: reissuePath) { reissueStarted.fulfill() }
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            keychain: keychain,
            server: server
        )
        let sentRefreshTokens = Recorder<String>()

        let waiter = Task { await store.recover(afterUnauthorized: "A1") }
        await fulfillment(of: [reissueStarted], timeout: AuthSessionStoreFixture.signalTimeout)
        let logout = Task {
            try await store.logout { refreshToken in
                await sentRefreshTokens.append(refreshToken)
            }
        }
        // 로그아웃이 재발급을 기다리기 시작한 뒤에 재발급 응답을 푼다
        let isLoggingOut = await waitUntilLoggingOut(store, currentToken: "A1")
        await server.release(reissuePath)
        try await logout.value
        _ = await waiter.value

        XCTAssertTrue(isLoggingOut, "로그아웃이 시작되지 않았다")
        let sent = await sentRefreshTokens.values
        XCTAssertEqual(sent, ["R2"])
        let inMemory = try await store.currentSession()
        XCTAssertNil(inMemory)
        let stored = try await AuthSessionStoreFixture.storedSession(in: keychain)
        XCTAssertNil(stored)
    }

    func test_로그아웃_중에_들어온_401은_재발급하지_않고_실패한다() async throws {
        let server = ScriptedNetworkClient()
        await server.reply(AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"), to: reissuePath)
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            server: server
        )
        let outcomesDuringLogout = Recorder<UnauthorizedRecovery>()

        try await store.logout { _ in
            // 서버 로그아웃 요청이 나가 있는 동안 다른 요청의 401 이 들어온다
            await outcomesDuringLogout.append(await store.recover(afterUnauthorized: "A1"))
        }

        let outcomes = await outcomesDuringLogout.values
        XCTAssertEqual(outcomes, [.fail])
        let reissueCount = await server.count(of: reissuePath)
        XCTAssertEqual(reissueCount, 0)
    }

    func test_탈퇴_뒤_키체인_삭제가_실패해도_세션은_메모리에서_지워진다() async throws {
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            keychain: keychain,
            server: ScriptedNetworkClient()
        )
        await keychain.setDeleteError(KeychainError.deleteFailed(status: -1))

        await store.clearAfterWithdrawal()

        let inMemory = try await store.currentSession()
        XCTAssertNil(inMemory)
    }
}
