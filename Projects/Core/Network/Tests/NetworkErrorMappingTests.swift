import CoreNetwork
import XCTest

private struct StatusCase {
    let statusCode: Int
    let message: String
    let expected: NetworkError
}

final class NetworkErrorMappingTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func test_status_mapping() async throws {
        let cases: [StatusCase] = [
            .init(statusCode: 400, message: "bad", expected: .badRequest(message: "bad")),
            .init(statusCode: 403, message: "no", expected: .forbidden(message: "no")),
            .init(statusCode: 404, message: "missing", expected: .notFound(message: "missing")),
            .init(statusCode: 409, message: "dup", expected: .conflict(message: "dup")),
            .init(
                statusCode: 418,
                message: "teapot",
                expected: .clientError(statusCode: 418, message: "teapot")
            ),
            .init(
                statusCode: 500,
                message: "boom",
                expected: .serverError(statusCode: 500, message: "boom")
            ),
        ]

        for item in cases {
            URLProtocolStub.reset()
            URLProtocolStub.requestHandler = { _ in
                let body = Data(#"{"message":"\#(item.message)"}"#.utf8)
                return .init(statusCode: item.statusCode, headers: [:], data: body)
            }

            let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
            let client = NetworkClientFactory.plain(
                config: NetworkConfiguration(baseURL: baseURL),
                session: TestSessionFactory.make()
            )

            do {
                struct Payload: Decodable, Sendable { let ok: Bool }
                let _: Payload = try await client.request(TestEndpoint())
                XCTFail("expected error for \(item.statusCode)")
            } catch let error as NetworkError {
                XCTAssertEqual(error, item.expected)
            } catch {
                XCTFail("unexpected \(error)")
            }
        }
    }

    func test_decoding_failed() async throws {
        URLProtocolStub.requestHandler = { _ in
            .init(statusCode: 200, headers: [:], data: Data(#"{"ok":"nope"}"#.utf8))
        }

        struct Payload: Decodable, Sendable { let ok: Bool }
        let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
        let client = NetworkClientFactory.plain(
            config: NetworkConfiguration(baseURL: baseURL),
            session: TestSessionFactory.make()
        )

        do {
            let _: Payload = try await client.request(TestEndpoint())
            XCTFail("expected decodingFailed")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
