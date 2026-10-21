import CoreNetwork
import CoreStorage
import Foundation
import XCTest

@testable import Data

final class AuthSessionStoreRefreshTests: XCTestCase {
    private let reissuePath = AuthStubFixture.reissuePath

    func test_재발급이_반영된_뒤_들어온_옛_토큰의_401은_재발급_없이_다시_보낸다() async throws {
        let server = ScriptedNetworkClient()
        await server.reply(AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"), to: reissuePath)
        await server.hold(reissuePath)
        let reissueStarted = XCTestExpectation(description: "재발급 요청이 닿는다")
        await server.onArrival(of: reissuePath) { reissueStarted.fulfill() }
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            server: server
        )

        let first = Task { await store.recover(afterUnauthorized: "A1") }
        await fulfillment(of: [reissueStarted], timeout: AuthSessionStoreFixture.signalTimeout)
        await server.release(reissuePath)
        let firstOutcome = await first.value
        // 둘째 요청도 A1 으로 나갔고, 그 401 은 재발급이 반영된 뒤에 들어온다
        let secondOutcome = await store.recover(afterUnauthorized: "A1")

        XCTAssertEqual(firstOutcome, .retry)
        XCTAssertEqual(secondOutcome, .retry)
        let reissueCount = await server.count(of: reissuePath)
        XCTAssertEqual(reissueCount, 1)
    }

    func test_재발급이_401로_끝난_직후_같은_토큰의_401_여러_개는_재발급을_다시_부르지_않는다() async throws {
        let server = ScriptedNetworkClient()
        await server.reply(.failure(.unauthorized), to: reissuePath)
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            server: server
        )

        let first = await store.recover(afterUnauthorized: "A1")
        let judgements = await store.judgeTogether(3, sentToken: "A1")

        XCTAssertEqual(first, .fail)
        XCTAssertEqual(judgements, [.fail, .fail, .fail])
        let reissueCount = await server.count(of: reissuePath)
        XCTAssertEqual(reissueCount, 1)
    }

    func test_재발급_401로_기억한_토큰으로_다시_401이_와도_재발급을_다시_부르지_않는다() async throws {
        let server = ScriptedNetworkClient()
        await server.reply(AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"), to: reissuePath)
        await server.reply(.failure(.unauthorized), to: reissuePath)
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            server: server
        )

        let rotated = await store.recover(afterUnauthorized: "A1")
        // 회전한 A2 로 재발급했고 서버가 401 로 거절한다
        let rejected = await store.recover(afterUnauthorized: "A2")
        let again = await store.recover(afterUnauthorized: "A2")

        XCTAssertEqual([rotated, rejected, again], [.retry, .fail, .fail])
        let sent = AuthSessionStoreFixture.refreshTokens(in: await server.bodies(of: reissuePath))
        XCTAssertEqual(sent, ["R1", "R2"])
    }

    func test_재발급_시작_전에_들어온_401_2개는_재발급을_한_번만_부른다() async throws {
        try await assertSingleRefresh(forUnauthorizedCount: 2)
    }

    func test_재발급_시작_전에_들어온_401_5개는_재발급을_한_번만_부른다() async throws {
        try await assertSingleRefresh(forUnauthorizedCount: 5)
    }

    func test_재발급_전송_실패는_기억하지도_지우지도_않아_다음_401에서_다시_재발급한다() async throws {
        let server = ScriptedNetworkClient()
        await server.reply(.failure(.transport(message: "timeout")), to: reissuePath)
        await server.reply(AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"), to: reissuePath)
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            server: server
        )

        let first = await store.recover(afterUnauthorized: "A1")
        let kept = try await store.currentSession()
        let second = await store.recover(afterUnauthorized: "A1")

        XCTAssertEqual(first, .fail)
        XCTAssertEqual(kept?.accessToken, "A1")
        XCTAssertEqual(second, .retry)
        let reissueCount = await server.count(of: reissuePath)
        XCTAssertEqual(reissueCount, 2)
    }

    func test_재발급은_토큰_두_개만_바꾸고_키체인에도_남긴다() async throws {
        let server = ScriptedNetworkClient()
        await server.reply(AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"), to: reissuePath)
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(userID: "42", isOnboardingCompleted: false),
            keychain: keychain,
            server: server
        )

        let outcome = await store.recover(afterUnauthorized: "A1")

        let expected = AuthSessionStoreFixture.session(
            access: "A2",
            refresh: "R2",
            userID: "42",
            isOnboardingCompleted: false
        )
        XCTAssertEqual(outcome, .retry)
        let inMemory = try await store.currentSession()
        XCTAssertEqual(inMemory, expected)
        let stored = try await AuthSessionStoreFixture.storedSession(in: keychain)
        XCTAssertEqual(stored, expected)
        let sent = AuthSessionStoreFixture.refreshTokens(in: await server.bodies(of: reissuePath))
        XCTAssertEqual(sent, ["R1"])
    }

    func test_재발급_결과의_키체인_저장이_실패해도_메모리의_새_토큰으로_계속_쓴다() async throws {
        let server = ScriptedNetworkClient()
        await server.reply(AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"), to: reissuePath)
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            keychain: keychain,
            server: server
        )
        await keychain.setSaveError(KeychainError.saveFailed(status: -1))

        let outcome = await store.recover(afterUnauthorized: "A1")

        XCTAssertEqual(outcome, .retry)
        let token = try await store.accessToken()
        XCTAssertEqual(token, "A2")
        let stored = try await AuthSessionStoreFixture.storedSession(in: keychain)
        XCTAssertEqual(stored?.accessToken, "A1")
    }

    private func assertSingleRefresh(
        forUnauthorizedCount count: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let server = ScriptedNetworkClient()
        await server.reply(AuthSessionStoreFixture.reissueReply(access: "A2", refresh: "R2"), to: reissuePath)
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            server: server
        )
        // 사본을 먼저 채운다. 채운 뒤에야 판단 N 개를 한 차례로 묶을 수 있다
        _ = try await store.currentSession()

        let judgements = await store.judgeTogether(count, sentToken: "A1")
        var outcomes: [UnauthorizedRecovery] = []
        for judgement in judgements {
            outcomes.append(await judgement.resolve())
        }

        XCTAssertEqual(outcomes, Array(repeating: .retry, count: count), file: file, line: line)
        let reissueCount = await server.count(of: reissuePath)
        XCTAssertEqual(reissueCount, 1, file: file, line: line)
    }
}
