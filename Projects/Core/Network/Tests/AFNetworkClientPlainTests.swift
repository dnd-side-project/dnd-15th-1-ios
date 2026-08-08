import CoreNetwork
import XCTest

final class AFNetworkClientPlainTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func test_plain_요청_성공_디코딩() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/users/me")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            return .init(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                data: Data(#"{"ok":true}"#.utf8)
            )
        }

        struct Payload: Decodable, Equatable, Sendable { let ok: Bool }
        let baseURL = try XCTUnwrap(URL(string: "https://api.example.invalid"))
        let client = AFNetworkClient.plain(
            configuration: NetworkConfiguration(baseURL: baseURL),
            session: TestSessionFactory.make()
        )

        let response: Payload = try await client.request(TestEndpoint())
        XCTAssertEqual(response, Payload(ok: true))
    }
}
