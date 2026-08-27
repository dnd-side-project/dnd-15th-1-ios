import CoreNetwork
import Foundation
import XCTest

final class AFNetworkClientAuthTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func test_authed_요청에_Bearer_부착() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer access-token"
            )
            return .init(statusCode: 200, headers: [:], data: Data(#"{"ok":true}"#.utf8))
        }

        struct Payload: Decodable, Sendable { let ok: Bool }
        let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
        let provider = StubTokenProvider(token: "access-token")
        let refresher = StubTokenRefresher(provider: provider)
        let interceptor = AuthRequestInterceptor(
            tokenProvider: provider,
            tokenRefresher: refresher
        )
        let networkConfig = NetworkConfiguration(baseURL: baseURL)
        let client = AFNetworkClient(
            session: TestSessionFactory.make(interceptor: interceptor),
            baseURL: networkConfig.baseURL,
            jsonDecoder: networkConfig.jsonDecoder
        )

        let _: Payload = try await client.request(TestEndpoint())
    }

    func test_http_URL이면_authorization_거부() async throws {
        URLProtocolStub.requestHandler = { _ in
            XCTFail("request should not be sent")
            return .init(statusCode: 200, headers: [:], data: Data())
        }

        let baseURL = try XCTUnwrap(URL(string: "http://api.example.invalid"))
        let provider = StubTokenProvider(token: "access-token")
        let refresher = StubTokenRefresher(provider: provider)
        let interceptor = AuthRequestInterceptor(
            tokenProvider: provider,
            tokenRefresher: refresher
        )
        let networkConfig = NetworkConfiguration(baseURL: baseURL)
        let client = AFNetworkClient(
            session: TestSessionFactory.make(interceptor: interceptor),
            baseURL: networkConfig.baseURL,
            jsonDecoder: networkConfig.jsonDecoder
        )

        do {
            struct Payload: Decodable, Sendable { let ok: Bool }
            let _: Payload = try await client.request(TestEndpoint())
            XCTFail("expected invalidURL")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func test_401_refresh_후_1회_재시도() async throws {
        final class State: @unchecked Sendable {
            private let lock = NSLock()
            private var count = 0

            func next() -> Int {
                lock.lock()
                defer { lock.unlock() }
                count += 1
                return count
            }
        }
        let state = State()

        URLProtocolStub.requestHandler = { request in
            let requestCount = state.next()
            if requestCount == 1 {
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Authorization"),
                    "Bearer access-token"
                )
                return .init(statusCode: 401, headers: [:], data: Data())
            }
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer access-token-refreshed"
            )
            return .init(statusCode: 200, headers: [:], data: Data(#"{"ok":true}"#.utf8))
        }

        struct Payload: Decodable, Equatable, Sendable { let ok: Bool }
        let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
        let provider = StubTokenProvider(token: "access-token")
        let refresher = StubTokenRefresher(provider: provider)
        let interceptor = AuthRequestInterceptor(
            tokenProvider: provider,
            tokenRefresher: refresher
        )
        let networkConfig = NetworkConfiguration(baseURL: baseURL)
        let client = AFNetworkClient(
            session: TestSessionFactory.make(interceptor: interceptor),
            baseURL: networkConfig.baseURL,
            jsonDecoder: networkConfig.jsonDecoder
        )

        let response: Payload = try await client.request(TestEndpoint())
        XCTAssertEqual(response, Payload(ok: true))
        let refreshCount = await refresher.refreshCount
        XCTAssertEqual(refreshCount, 1)
    }

    func test_동시_401은_refresh_single_flight() async throws {
        URLProtocolStub.requestHandler = { request in
            if (request.value(forHTTPHeaderField: "Authorization") ?? "")
                .contains("access-token-refreshed") == false {
                return .init(statusCode: 401, headers: [:], data: Data())
            }
            return .init(statusCode: 200, headers: [:], data: Data(#"{"ok":true}"#.utf8))
        }

        struct Payload: Decodable, Sendable { let ok: Bool }
        let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
        let provider = StubTokenProvider(token: "access-token")
        let refresher = StubTokenRefresher(provider: provider)
        await refresher.setDelayNanoseconds(100_000_000)
        let interceptor = AuthRequestInterceptor(
            tokenProvider: provider,
            tokenRefresher: refresher
        )
        let networkConfig = NetworkConfiguration(baseURL: baseURL)
        let client = AFNetworkClient(
            session: TestSessionFactory.make(interceptor: interceptor),
            baseURL: networkConfig.baseURL,
            jsonDecoder: networkConfig.jsonDecoder
        )

        async let first: Payload = client.request(TestEndpoint(path: "/a"))
        async let second: Payload = client.request(TestEndpoint(path: "/b"))
        _ = try await (first, second)

        let refreshCount = await refresher.refreshCount
        XCTAssertEqual(refreshCount, 1)
    }

    func test_refresh_실패시_unauthorized() async throws {
        URLProtocolStub.requestHandler = { _ in
            .init(statusCode: 401, headers: [:], data: Data())
        }

        struct Payload: Decodable, Sendable { let ok: Bool }
        let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
        let provider = StubTokenProvider(token: "access-token")
        let refresher = StubTokenRefresher(provider: provider)
        await refresher.setError(NetworkError.unauthorized)
        let interceptor = AuthRequestInterceptor(
            tokenProvider: provider,
            tokenRefresher: refresher
        )
        let networkConfig = NetworkConfiguration(baseURL: baseURL)
        let client = AFNetworkClient(
            session: TestSessionFactory.make(interceptor: interceptor),
            baseURL: networkConfig.baseURL,
            jsonDecoder: networkConfig.jsonDecoder
        )

        do {
            let _: Payload = try await client.request(TestEndpoint())
            XCTFail("expected unauthorized")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func test_토큰이_이미_갱신됐으면_재발급_없이_재시도한다() async throws {
        let provider = SyncTokenProvider(token: "old-token")

        URLProtocolStub.requestHandler = { request in
            let authorization = request.value(forHTTPHeaderField: "Authorization")
            if authorization == "Bearer old-token" {
                // 다른 요청이 이미 재발급을 끝낸 상황을 만든다
                provider.setToken("new-token")
                return .init(statusCode: 401, headers: [:], data: Data())
            }
            XCTAssertEqual(authorization, "Bearer new-token")
            return .init(statusCode: 200, headers: [:], data: Data(#"{"ok":true}"#.utf8))
        }

        struct Payload: Decodable, Equatable, Sendable { let ok: Bool }
        let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
        let refresher = StubTokenRefresher(provider: nil, nextToken: nil)
        let interceptor = AuthRequestInterceptor(
            tokenProvider: provider,
            tokenRefresher: refresher
        )
        let networkConfig = NetworkConfiguration(baseURL: baseURL)
        let client = AFNetworkClient(
            session: TestSessionFactory.make(interceptor: interceptor),
            baseURL: networkConfig.baseURL,
            jsonDecoder: networkConfig.jsonDecoder
        )

        let response: Payload = try await client.request(TestEndpoint())
        XCTAssertEqual(response, Payload(ok: true))

        let refreshCount = await refresher.refreshCount
        XCTAssertEqual(refreshCount, 0)
    }

    func test_재발급_실패_직후_401은_재발급을_다시_부르지_않는다() async throws {
        URLProtocolStub.requestHandler = { _ in
            .init(statusCode: 401, headers: [:], data: Data())
        }

        struct Payload: Decodable, Sendable { let ok: Bool }
        let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
        let provider = StubTokenProvider(token: "access-token")
        let refresher = StubTokenRefresher(provider: provider, nextToken: nil)
        await refresher.setError(NetworkError.unauthorized)
        let interceptor = AuthRequestInterceptor(
            tokenProvider: provider,
            tokenRefresher: refresher
        )
        let networkConfig = NetworkConfiguration(baseURL: baseURL)
        let client = AFNetworkClient(
            session: TestSessionFactory.make(interceptor: interceptor),
            baseURL: networkConfig.baseURL,
            jsonDecoder: networkConfig.jsonDecoder
        )

        for _ in 0..<2 {
            do {
                let _: Payload = try await client.request(TestEndpoint())
                XCTFail("expected unauthorized")
            } catch let error as NetworkError {
                XCTAssertEqual(error, .unauthorized)
            } catch {
                XCTFail("unexpected \(error)")
            }
        }

        let refreshCount = await refresher.refreshCount
        XCTAssertEqual(refreshCount, 1)
    }
}

extension AFNetworkClientAuthTests {
    func test_전송_실패는_기억하지_않아_다음_401에서_재발급을_다시_시도한다() async throws {
        URLProtocolStub.requestHandler = { request in
            if (request.value(forHTTPHeaderField: "Authorization") ?? "")
                .contains("access-token-refreshed") == false {
                return .init(statusCode: 401, headers: [:], data: Data())
            }
            return .init(statusCode: 200, headers: [:], data: Data(#"{"ok":true}"#.utf8))
        }

        struct Payload: Decodable, Equatable, Sendable { let ok: Bool }
        let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
        let provider = StubTokenProvider(token: "access-token")
        let refresher = StubTokenRefresher(provider: provider)
        await refresher.setError(URLError(.timedOut))
        let interceptor = AuthRequestInterceptor(
            tokenProvider: provider,
            tokenRefresher: refresher
        )
        let networkConfig = NetworkConfiguration(baseURL: baseURL)
        let client = AFNetworkClient(
            session: TestSessionFactory.make(interceptor: interceptor),
            baseURL: networkConfig.baseURL,
            jsonDecoder: networkConfig.jsonDecoder
        )

        // 1회차: 재발급이 전송 실패로 끝난다. 기억하면 안 된다.
        do {
            let _: Payload = try await client.request(TestEndpoint())
            XCTFail("expected unauthorized")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("unexpected \(error)")
        }

        await refresher.setError(nil)

        // 2회차: 재발급을 다시 시도해 성공해야 한다.
        let response: Payload = try await client.request(TestEndpoint())
        XCTAssertEqual(response, Payload(ok: true))

        let refreshCount = await refresher.refreshCount
        XCTAssertEqual(refreshCount, 2)
    }

    func test_재발급이_실패해도_요청_하나가_부르는_재발급은_1회다() async throws {
        URLProtocolStub.requestHandler = { _ in
            .init(statusCode: 401, headers: [:], data: Data())
        }

        struct Payload: Decodable, Sendable { let ok: Bool }
        let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
        let provider = StubTokenProvider(token: "access-token")
        let refresher = StubTokenRefresher(provider: provider)
        await refresher.setError(URLError(.timedOut))
        let interceptor = AuthRequestInterceptor(
            tokenProvider: provider,
            tokenRefresher: refresher
        )
        let networkConfig = NetworkConfiguration(baseURL: baseURL)
        let client = AFNetworkClient(
            session: TestSessionFactory.make(interceptor: interceptor),
            baseURL: networkConfig.baseURL,
            jsonDecoder: networkConfig.jsonDecoder
        )

        do {
            let _: Payload = try await client.request(TestEndpoint())
            XCTFail("expected unauthorized")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("unexpected \(error)")
        }

        let refreshCount = await refresher.refreshCount
        XCTAssertEqual(refreshCount, 1)
    }
}
