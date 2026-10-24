import CoreNetwork
import Foundation
import XCTest

final class AFNetworkClientAuthTests: XCTestCase {
    private struct Payload: Decodable, Equatable, Sendable {
        let ok: Bool
    }

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func test_인증_요청에_Bearer_토큰을_붙인다() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer access-token"
            )
            return .init(statusCode: 200, headers: [:], data: Data(#"{"ok":true}"#.utf8))
        }
        let client = try makeClient(provider: StubSessionProvider(token: "access-token"))

        let _: Payload = try await client.request(TestEndpoint())
    }

    func test_https가_아닌_주소로는_토큰을_보내지_않고_실패한다() async throws {
        URLProtocolStub.requestHandler = { _ in
            XCTFail("request should not be sent")
            return .init(statusCode: 200, headers: [:], data: Data())
        }
        let client = try makeClient(
            provider: StubSessionProvider(token: "access-token"),
            baseURL: "http://api.example.invalid"
        )

        do {
            let _: Payload = try await client.request(TestEndpoint())
            XCTFail("expected invalidURL")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func test_401을_받으면_토큰을_다시_읽지_않고_보낸_토큰으로_세션에_묻는다() async throws {
        URLProtocolStub.requestHandler = { _ in
            .init(statusCode: 401, headers: [:], data: Data())
        }
        let provider = StubSessionProvider(token: "access-token", recovery: .fail)
        let client = try makeClient(provider: provider)

        await assertUnauthorized {
            let _: Payload = try await client.request(TestEndpoint())
        }

        let recovered = await provider.recoveredTokens
        XCTAssertEqual(recovered, ["access-token"])
        let reads = await provider.accessTokenReads
        XCTAssertEqual(reads, 1)
    }

    func test_세션이_다시_보내라고_하면_그때의_토큰으로_다시_보낸다() async throws {
        URLProtocolStub.requestHandler = { request in
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer access-token-refreshed" {
                return .init(statusCode: 200, headers: [:], data: Data(#"{"ok":true}"#.utf8))
            }
            return .init(statusCode: 401, headers: [:], data: Data())
        }
        let provider = StubSessionProvider(
            token: "access-token",
            recovery: .retry,
            tokenAfterRecovery: "access-token-refreshed"
        )
        let client = try makeClient(provider: provider)

        let response: Payload = try await client.request(TestEndpoint())

        XCTAssertEqual(response, Payload(ok: true))
        XCTAssertEqual(
            URLProtocolStub.requests.map { $0.value(forHTTPHeaderField: "Authorization") },
            ["Bearer access-token", "Bearer access-token-refreshed"]
        )
    }

    func test_세션이_실패라고_하면_인증_실패로_끝나고_다시_보내지_않는다() async throws {
        URLProtocolStub.requestHandler = { _ in
            .init(statusCode: 401, headers: [:], data: Data())
        }
        let client = try makeClient(provider: StubSessionProvider(recovery: .fail))

        await assertUnauthorized {
            let _: Payload = try await client.request(TestEndpoint())
        }

        XCTAssertEqual(URLProtocolStub.requests.count, 1)
    }

    func test_토큰_없이_보낸_요청의_401은_토큰_없이_세션에_묻는다() async throws {
        URLProtocolStub.requestHandler = { _ in
            .init(statusCode: 401, headers: [:], data: Data())
        }
        let provider = StubSessionProvider(token: nil, recovery: .fail)
        let client = try makeClient(provider: provider)

        await assertUnauthorized {
            let _: Payload = try await client.request(TestEndpoint())
        }

        XCTAssertNil(URLProtocolStub.requests.first?.value(forHTTPHeaderField: "Authorization"))
        let recovered = await provider.recoveredTokens
        XCTAssertEqual(recovered, [nil])
    }

    func test_다시_보낸_요청이_또_401이면_세션에_다시_묻지_않는다() async throws {
        URLProtocolStub.requestHandler = { _ in
            .init(statusCode: 401, headers: [:], data: Data())
        }
        let provider = StubSessionProvider(recovery: .retry)
        let client = try makeClient(provider: provider)

        await assertUnauthorized {
            let _: Payload = try await client.request(TestEndpoint())
        }

        let recovered = await provider.recoveredTokens
        XCTAssertEqual(recovered.count, 1)
        XCTAssertEqual(URLProtocolStub.requests.count, 2)
    }

    private func makeClient(
        provider: StubSessionProvider,
        baseURL: String = "https://api.example.invalid"
    ) throws -> AFNetworkClient {
        let url = try XCTUnwrap(URL(string: baseURL))
        let networkConfig = NetworkConfiguration(baseURL: url)
        return AFNetworkClient(
            session: TestSessionFactory.make(
                interceptor: AuthRequestInterceptor(sessionProvider: provider)
            ),
            baseURL: networkConfig.baseURL,
            jsonDecoder: networkConfig.jsonDecoder
        )
    }

    private func assertUnauthorized(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("expected unauthorized", file: file, line: line)
        } catch let error as NetworkError {
            XCTAssertEqual(error, .unauthorized, file: file, line: line)
        } catch {
            XCTFail("unexpected \(error)", file: file, line: line)
        }
    }
}
