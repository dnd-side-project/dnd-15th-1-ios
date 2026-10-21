import CoreNetwork
import CoreStorage
import Foundation
import XCTest

@testable import Data

final class AuthSessionStoreSessionTests: XCTestCase {
    private let reissuePath = AuthStubFixture.reissuePath

    func test_재발급_응답을_붙잡은_채_새_로그인을_끝내면_새_세션이_남는다() async throws {
        let server = ScriptedNetworkClient()
        let reissueStarted = await holdReissue(on: server)
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(userID: "1"),
            keychain: keychain,
            server: server
        )
        let newAccount = AuthSessionStoreFixture.session(access: "B1", refresh: "S1", userID: "2")

        let waiter = Task { await store.recover(afterUnauthorized: "A1") }
        await fulfillment(of: [reissueStarted], timeout: AuthSessionStoreFixture.signalTimeout)
        try await store.login(newAccount)
        await server.release(reissuePath)
        let outcome = await waiter.value

        XCTAssertEqual(outcome, .fail)
        let inMemory = try await store.currentSession()
        XCTAssertEqual(inMemory, newAccount)
        let stored = try await AuthSessionStoreFixture.storedSession(in: keychain)
        XCTAssertEqual(stored, newAccount)
    }

    func test_재발급을_반영한_뒤_키체인_저장을_기다리는_사이_새_로그인이_끝나면_기다리던_요청은_실패한다() async throws {
        let server = ScriptedNetworkClient()
        let reissueStarted = await holdReissue(on: server)
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(userID: "1"),
            keychain: keychain,
            server: server
        )
        let newAccount = AuthSessionStoreFixture.session(access: "B1", refresh: "S1", userID: "2")
        let loginSaveArrived = XCTestExpectation(description: "로그인 저장이 키체인에 닿는다")
        loginSaveArrived.assertForOverFulfill = false

        let waiter = Task { await store.recover(afterUnauthorized: "A1") }
        await fulfillment(of: [reissueStarted], timeout: AuthSessionStoreFixture.signalTimeout)
        await keychain.holdSaves { loginSaveArrived.fulfill() }
        let login = Task { try await store.login(newAccount) }
        await fulfillment(of: [loginSaveArrived], timeout: AuthSessionStoreFixture.signalTimeout)
        // 로그인 저장이 붙잡힌 사이 재발급이 반영되고, 그 키체인 쓰기는 로그인 쓰기 뒤에 줄을 선다
        await server.release(reissuePath)
        let isRotated = await waitUntilAccessToken(store, is: "A2")
        await keychain.releaseSaves()
        try await login.value
        let outcome = await waiter.value

        XCTAssertTrue(isRotated, "재발급이 반영되지 않았다")
        XCTAssertEqual(outcome, .fail)
        let inMemory = try await store.currentSession()
        XCTAssertEqual(inMemory, newAccount)
        let stored = try await AuthSessionStoreFixture.storedSession(in: keychain)
        XCTAssertEqual(stored, newAccount)
    }

    func test_재발급_중에_바꾼_온보딩_플래그가_재발급_뒤에도_남는다() async throws {
        let server = ScriptedNetworkClient()
        let reissueStarted = await holdReissue(on: server)
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(isOnboardingCompleted: false),
            keychain: keychain,
            server: server
        )

        let waiter = Task { await store.recover(afterUnauthorized: "A1") }
        await fulfillment(of: [reissueStarted], timeout: AuthSessionStoreFixture.signalTimeout)
        try await store.updateOnboardingCompleted(true)
        await server.release(reissuePath)
        let outcome = await waiter.value

        let expected = AuthSessionStoreFixture.session(access: "A2", refresh: "R2", isOnboardingCompleted: true)
        XCTAssertEqual(outcome, .retry)
        let inMemory = try await store.currentSession()
        XCTAssertEqual(inMemory, expected)
        let stored = try await AuthSessionStoreFixture.storedSession(in: keychain)
        XCTAssertEqual(stored, expected)
    }

    func test_앞_세션_토큰으로_보낸_요청의_401은_새_로그인_뒤_재발급_없이_실패한다() async throws {
        let server = ScriptedNetworkClient()
        await server.reply(AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"), to: reissuePath)
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            server: server
        )
        // 앞 세션의 A1 을 요청에 실어 보낸 상태를 만든다
        _ = try await store.accessToken()
        try await store.login(AuthSessionStoreFixture.session(access: "B1", refresh: "S1", userID: "2"))

        let outcome = await store.recover(afterUnauthorized: "A1")

        XCTAssertEqual(outcome, .fail)
        let reissueCount = await server.count(of: reissuePath)
        XCTAssertEqual(reissueCount, 0)
    }

    func test_토큰_없이_보낸_요청의_401은_재발급_없이_실패한다() async throws {
        let server = ScriptedNetworkClient()
        await server.reply(AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"), to: reissuePath)
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            server: server
        )

        let outcome = await store.recover(afterUnauthorized: nil)

        XCTAssertEqual(outcome, .fail)
        let reissueCount = await server.count(of: reissuePath)
        XCTAssertEqual(reissueCount, 0)
    }

    func test_세션은_처음_불릴_때_한_번만_키체인에서_읽는다() async throws {
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            keychain: keychain,
            server: ScriptedNetworkClient()
        )

        let token = try await store.accessToken()
        let session = try await store.currentSession()
        let outcome = await store.recover(afterUnauthorized: nil)

        XCTAssertEqual(token, "A1")
        XCTAssertEqual(session?.userID, "1")
        XCTAssertEqual(outcome, .fail)
        let loadCount = await keychain.loadCount
        XCTAssertEqual(loadCount, 1)
    }

    func test_사본_채우기가_실패하면_그_호출만_실패하고_다음_호출이_다시_읽는다() async throws {
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            keychain: keychain,
            server: ScriptedNetworkClient()
        )
        // -25308 은 잠금 해제 전이라 읽지 못한 경우다. 세션이 없는 것과 다른 사실이다
        await keychain.setLoadError(KeychainError.loadFailed(status: -25308))

        await assertThrows(KeychainError.loadFailed(status: -25308)) {
            try await store.accessToken()
        }
        let outcomeWhileFailing = await store.recover(afterUnauthorized: "A1")
        await keychain.setLoadError(nil)
        let token = try await store.accessToken()

        XCTAssertEqual(outcomeWhileFailing, .fail)
        XCTAssertEqual(token, "A1")
    }

    func test_첫_읽기가_끝나기_전에_로그인하면_로그인한_세션이_남는다() async throws {
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            keychain: keychain,
            server: ScriptedNetworkClient()
        )
        let loadArrived = XCTestExpectation(description: "첫 읽기가 키체인에 닿는다")
        await keychain.holdLoads { loadArrived.fulfill() }
        let newAccount = AuthSessionStoreFixture.session(access: "B1", refresh: "S1", userID: "2")

        let reader = Task { try await store.accessToken() }
        await fulfillment(of: [loadArrived], timeout: AuthSessionStoreFixture.signalTimeout)
        try await store.login(newAccount)
        await keychain.releaseLoads()
        let token = try await reader.value

        XCTAssertEqual(token, "B1")
        let inMemory = try await store.currentSession()
        XCTAssertEqual(inMemory, newAccount)
    }

    func test_로그인_저장이_실패하면_로그인이_실패하고_메모리는_그대로다() async throws {
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            keychain: keychain,
            server: ScriptedNetworkClient()
        )
        _ = try await store.currentSession()
        await keychain.setSaveError(KeychainError.saveFailed(status: -1))

        await assertThrows(KeychainError.saveFailed(status: -1)) {
            try await store.login(AuthSessionStoreFixture.session(access: "B1", refresh: "S1", userID: "2"))
        }

        let inMemory = try await store.currentSession()
        XCTAssertEqual(inMemory?.accessToken, "A1")
    }

    /// 재발급 응답을 A2/R2 로 정해 두고 붙잡는다. 돌려준 기대는 재발급 요청이 닿으면 채워진다
    private func holdReissue(on server: ScriptedNetworkClient) async -> XCTestExpectation {
        await server.reply(AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"), to: reissuePath)
        await server.hold(reissuePath)
        let reissueStarted = XCTestExpectation(description: "재발급 요청이 닿는다")
        await server.onArrival(of: reissuePath) { reissueStarted.fulfill() }
        return reissueStarted
    }
}
