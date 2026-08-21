import CoreNetwork
import Domain
import XCTest

@testable import Data

final class CourseErrorMapperTests: XCTestCase {

    func test_전송_에러를_network로_매핑한다() {
        let mapped = CourseErrorMapper.map(NetworkError.transport(message: "offline"))

        XCTAssertEqual(mapped, .network)
    }

    func test_인증_실패를_unauthorized로_매핑한다() {
        XCTAssertEqual(CourseErrorMapper.map(NetworkError.unauthorized), .unauthorized)
    }

    func test_못찾음을_notFound로_매핑한다() {
        let mapped = CourseErrorMapper.map(NetworkError.notFound(message: nil))

        XCTAssertEqual(mapped, .notFound)
    }

    func test_나머지_상태는_unknown으로_묶는다() {
        let errors: [NetworkError] = [
            .badRequest(message: nil),
            .forbidden(message: nil),
            .conflict(message: nil),
            .clientError(statusCode: 418, message: nil),
            .serverError(statusCode: 500, message: nil),
            .decodingFailed,
            .invalidResponse,
            .invalidURL,
        ]

        for error in errors {
            XCTAssertEqual(CourseErrorMapper.map(error), .unknown, "\(error)")
        }
    }

    func test_이미_도메인_에러면_그대로_통과시킨다() {
        XCTAssertEqual(CourseErrorMapper.map(CourseError.tooFewPlaces), .tooFewPlaces)
    }
}
