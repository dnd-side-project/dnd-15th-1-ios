import CoreNetwork
import Domain
import XCTest

@testable import Data

final class NoticeErrorMapperTests: XCTestCase {
    func test_전송_에러를_network로_매핑한다() {
        XCTAssertEqual(
            NoticeErrorMapper.map(NetworkError.transport(message: "offline")),
            .network
        )
    }

    func test_전송_에러가_아닌_네트워크_에러는_모두_unknown으로_매핑한다() {
        let errors: [NetworkError] = [
            .unauthorized,
            .notFound(message: nil),
            .badRequest(message: "invalid"),
            .forbidden(message: nil),
            .conflict(message: nil),
            .clientError(statusCode: 429, message: nil),
            .serverError(statusCode: 500, message: nil),
            .decodingFailed,
            .invalidResponse,
            .invalidURL,
        ]

        for error in errors {
            XCTAssertEqual(NoticeErrorMapper.map(error), .unknown, "\(error)")
        }
    }

    func test_이미_NoticeError면_그대로_통과시킨다() {
        XCTAssertEqual(NoticeErrorMapper.map(NoticeError.network), .network)
    }

    func test_알_수_없는_에러를_unknown으로_매핑한다() {
        struct SomeError: Error {}

        XCTAssertEqual(NoticeErrorMapper.map(SomeError()), .unknown)
    }
}
