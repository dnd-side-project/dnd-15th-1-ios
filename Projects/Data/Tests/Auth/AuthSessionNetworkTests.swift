import CoreNetwork
import Foundation
import XCTest

@testable import Data

/// 인터셉터·네트워크 클라이언트·세션 주인을 실제로 이어 401 뒤의 동작을 끝까지 본다.
/// 판단 순서를 강제하는 테스트는 `AuthSessionStoreRefreshTests` 에 있다. 여기는 이어 붙인 결과만 본다.
final class AuthSessionNetworkTests: XCTestCase {
    private struct Payload: Decodable, Equatable, Sendable {
        let ok: Bool
    }

    private struct ProbeEndpoint: APIEndpoint {
        var path = "/api/v1/members/me"
        var method: HTTPMethod { .get }
    }

    private static let oldAuthorization = "Bearer access-token"
    private static let newAuthorization = "Bearer access-token-refreshed"
    private static let refreshed = AuthSessionStoreFixture.reissueReply(
        access: "access-token-refreshed",
        refresh: "refresh-token-refreshed"
    )

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func test_401을_받으면_재발급한_뒤_새_토큰으로_다시_보낸다() async throws {
        URLProtocolStub.requestHandler = { AuthSessionNetworkTests.acceptsOnlyRefreshedToken($0) }
        let server = ScriptedNetworkClient()
        await server.reply(Self.refreshed, to: AuthStubFixture.reissuePath)
        let store = try await makeStore(server: server)
        let client = try makeClient(store: store)

        let response: Payload = try await client.request(ProbeEndpoint())

        XCTAssertEqual(response, Payload(ok: true))
        XCTAssertEqual(
            URLProtocolStub.requests.map { $0.value(forHTTPHeaderField: "Authorization") },
            [Self.oldAuthorization, Self.newAuthorization]
        )
        let reissueCount = await server.count(of: AuthStubFixture.reissuePath)
        XCTAssertEqual(reissueCount, 1)
    }

    func test_동시에_401을_받은_두_요청은_재발급을_한_번만_부른다() async throws {
        let oldTokenRequests = XCTestExpectation(description: "두 요청이 옛 토큰으로 나간다")
        oldTokenRequests.expectedFulfillmentCount = 2
        URLProtocolStub.requestHandler = { request in
            let response = AuthSessionNetworkTests.acceptsOnlyRefreshedToken(request)
            if response.statusCode == 401 {
                oldTokenRequests.fulfill()
            }
            return response
        }
        let server = ScriptedNetworkClient()
        await server.reply(Self.refreshed, to: AuthStubFixture.reissuePath)
        await server.hold(AuthStubFixture.reissuePath)
        let reissueStarted = XCTestExpectation(description: "재발급 요청이 닿는다")
        await server.onArrival(of: AuthStubFixture.reissuePath) { reissueStarted.fulfill() }
        let store = try await makeStore(server: server)
        let client = try makeClient(store: store)

        async let first: Payload = client.request(ProbeEndpoint(path: "/a"))
        async let second: Payload = client.request(ProbeEndpoint(path: "/b"))
        // 두 요청이 옛 토큰으로 나가고 재발급이 시작된 뒤에 재발급을 풀어 준다
        await fulfillment(
            of: [oldTokenRequests, reissueStarted],
            timeout: AuthSessionStoreFixture.signalTimeout
        )
        await server.release(AuthStubFixture.reissuePath)
        let responses = try await [first, second]

        XCTAssertEqual(responses, [Payload(ok: true), Payload(ok: true)])
        let reissueCount = await server.count(of: AuthStubFixture.reissuePath)
        XCTAssertEqual(reissueCount, 1)
    }

    func test_재발급이_실패하면_요청은_인증_실패로_끝난다() async throws {
        URLProtocolStub.requestHandler = { _ in AuthSessionNetworkTests.unauthorizedResponse }
        let server = ScriptedNetworkClient()
        await server.reply(.failure(.unauthorized), to: AuthStubFixture.reissuePath)
        let store = try await makeStore(server: server)
        let client = try makeClient(store: store)

        await assertThrows(NetworkError.unauthorized) {
            try await client.request(ProbeEndpoint()) as Payload
        }
    }

    func test_재발급_실패_직후_401은_재발급을_다시_부르지_않는다() async throws {
        URLProtocolStub.requestHandler = { _ in AuthSessionNetworkTests.unauthorizedResponse }
        let server = ScriptedNetworkClient()
        await server.reply(.failure(.unauthorized), to: AuthStubFixture.reissuePath)
        let store = try await makeStore(server: server)
        let client = try makeClient(store: store)

        for _ in 0..<2 {
            await assertThrows(NetworkError.unauthorized) {
                try await client.request(ProbeEndpoint()) as Payload
            }
        }

        let reissueCount = await server.count(of: AuthStubFixture.reissuePath)
        XCTAssertEqual(reissueCount, 1)
    }

    func test_전송_실패는_기억하지_않아_다음_401에서_재발급을_다시_시도한다() async throws {
        URLProtocolStub.requestHandler = { AuthSessionNetworkTests.acceptsOnlyRefreshedToken($0) }
        let server = ScriptedNetworkClient()
        await server.reply(.failure(.transport(message: "timeout")), to: AuthStubFixture.reissuePath)
        await server.reply(Self.refreshed, to: AuthStubFixture.reissuePath)
        let store = try await makeStore(server: server)
        let client = try makeClient(store: store)

        // 1회차: 재발급이 전송 실패로 끝난다. 기억하면 안 된다.
        await assertThrows(NetworkError.unauthorized) {
            try await client.request(ProbeEndpoint()) as Payload
        }
        // 2회차: 재발급을 다시 시도해 성공해야 한다.
        let response: Payload = try await client.request(ProbeEndpoint())

        XCTAssertEqual(response, Payload(ok: true))
        let reissueCount = await server.count(of: AuthStubFixture.reissuePath)
        XCTAssertEqual(reissueCount, 2)
    }

    func test_재발급이_실패해도_요청_하나가_부르는_재발급은_1회다() async throws {
        URLProtocolStub.requestHandler = { _ in AuthSessionNetworkTests.unauthorizedResponse }
        let server = ScriptedNetworkClient()
        await server.reply(.failure(.transport(message: "timeout")), to: AuthStubFixture.reissuePath)
        let store = try await makeStore(server: server)
        let client = try makeClient(store: store)

        await assertThrows(NetworkError.unauthorized) {
            try await client.request(ProbeEndpoint()) as Payload
        }

        let reissueCount = await server.count(of: AuthStubFixture.reissuePath)
        XCTAssertEqual(reissueCount, 1)
    }

    func test_로그아웃_요청의_401은_인터셉터가_다시_보내지_않고_세션_주인이_새_리프레시_토큰으로_한_번_더_보낸다() async throws {
        URLProtocolStub.requestHandler = { AuthSessionNetworkTests.acceptsOnlyRefreshedToken($0) }
        let server = ScriptedNetworkClient()
        await server.reply(Self.refreshed, to: AuthStubFixture.reissuePath)
        let store = try await makeStore(server: server)
        let client = try makeClient(store: store)
        let remote = AuthRemoteDataSource(plainClient: server, authedClient: client)

        try await store.logout { refreshToken in
            try await remote.logout(refreshToken: refreshToken)
        }

        let logoutRequests = URLProtocolStub.requests.filter { $0.url?.path == AuthStubFixture.logoutPath }
        XCTAssertEqual(
            logoutRequests.map { $0.value(forHTTPHeaderField: "Authorization") },
            [Self.oldAuthorization, Self.newAuthorization]
        )
        XCTAssertEqual(
            AuthSessionStoreFixture.refreshTokens(in: logoutRequests.map(\.httpBody)),
            ["refresh-token", "refresh-token-refreshed"]
        )
        let reissueCount = await server.count(of: AuthStubFixture.reissuePath)
        XCTAssertEqual(reissueCount, 1)
        let inMemory = try await store.currentSession()
        XCTAssertNil(inMemory)
    }

    func test_재발급을_기다리던_두_요청은_그사이_새_로그인이_끝나면_인증_실패로_끝나고_새_토큰으로_다시_나가지_않는다() async throws {
        URLProtocolStub.requestHandler = { _ in AuthSessionNetworkTests.unauthorizedResponse }
        let server = ScriptedNetworkClient()
        await server.reply(Self.refreshed, to: AuthStubFixture.reissuePath)
        await server.hold(AuthStubFixture.reissuePath)
        let joined = XCTestExpectation(description: "두 401 이 진행 중인 재발급에 합류한다")
        joined.expectedFulfillmentCount = 2
        let store = try await makeStore(server: server)
        let client = try makeClient(provider: JoinObservingSessionProvider(store: store) { joined.fulfill() })

        let first = Task { try await client.request(ProbeEndpoint(path: "/a")) as Payload }
        let second = Task { try await client.request(ProbeEndpoint(path: "/b")) as Payload }
        // 두 요청이 모두 재발급을 기다리는 상태에서 새 로그인을 끝내고 재발급 응답을 푼다
        await fulfillment(of: [joined], timeout: AuthSessionStoreFixture.signalTimeout)
        try await store.login(AuthSessionStoreFixture.session(access: "B1", refresh: "S1", userID: "2"))
        await server.release(AuthStubFixture.reissuePath)

        await assertThrows(NetworkError.unauthorized) { try await first.value }
        await assertThrows(NetworkError.unauthorized) { try await second.value }
        let authorizations = URLProtocolStub.requests.map { $0.value(forHTTPHeaderField: "Authorization") }
        XCTAssertEqual(authorizations, [Self.oldAuthorization, Self.oldAuthorization])
        let reissueCount = await server.count(of: AuthStubFixture.reissuePath)
        XCTAssertEqual(reissueCount, 1)
        let token = try await store.accessToken()
        XCTAssertEqual(token, "B1")
    }

    private static let unauthorizedResponse = URLProtocolStub.StubResponse(
        statusCode: 401,
        headers: [:],
        data: Data()
    )

    /// 새 토큰을 실은 요청만 받아 주고 나머지는 401 로 돌려보낸다
    private static func acceptsOnlyRefreshedToken(_ request: URLRequest) -> URLProtocolStub.StubResponse {
        guard request.value(forHTTPHeaderField: "Authorization") == newAuthorization else {
            return unauthorizedResponse
        }
        return URLProtocolStub.StubResponse(statusCode: 200, headers: [:], data: Data(#"{"ok":true}"#.utf8))
    }

    private func makeStore(server: ScriptedNetworkClient) async throws -> AuthSessionStore {
        try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(access: "access-token", refresh: "refresh-token"),
            server: server
        )
    }

    private func makeClient(store: AuthSessionStore) throws -> AFNetworkClient {
        try makeClient(provider: store)
    }

    private func makeClient(provider: any AuthSessionProviding) throws -> AFNetworkClient {
        let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
        return AFNetworkClient(
            session: TestSessionFactory.make(interceptor: AuthRequestInterceptor(sessionProvider: provider)),
            baseURL: baseURL,
            jsonDecoder: NetworkJSONCoding.makeDecoder()
        )
    }
}

/// 401 판단이 진행 중인 재발급을 기다리게 된 순간을 알린다.
/// 사본은 요청을 보낼 때 이미 채워졌으므로 `recover` 와 같은 길을 판단과 기다림으로 나눠 부른다.
private final class JoinObservingSessionProvider: AuthSessionProviding {
    private let store: AuthSessionStore
    private let onJoin: @Sendable () -> Void

    init(store: AuthSessionStore, onJoin: @escaping @Sendable () -> Void) {
        self.store = store
        self.onJoin = onJoin
    }

    func accessToken() async throws -> String? {
        try await store.accessToken()
    }

    func recover(afterUnauthorized sentToken: String?) async -> UnauthorizedRecovery {
        let judgement = await store.judgeUnauthorized(sentToken: sentToken)
        if case .awaitRefresh = judgement {
            onJoin()
        }
        return await judgement.resolve()
    }
}
