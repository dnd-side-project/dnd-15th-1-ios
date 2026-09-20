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

    func test_인증_실패를_unknown으로_매핑한다() {
        XCTAssertEqual(NoticeErrorMapper.map(NetworkError.unauthorized), .unknown)
    }

    func test_notFound를_unknown으로_매핑한다() {
        XCTAssertEqual(NoticeErrorMapper.map(NetworkError.notFound(message: nil)), .unknown)
    }

    func test_badRequest를_unknown으로_매핑한다() {
        XCTAssertEqual(
            NoticeErrorMapper.map(NetworkError.badRequest(message: "invalid")),
            .unknown
        )
    }

    func test_forbidden을_unknown으로_매핑한다() {
        XCTAssertEqual(NoticeErrorMapper.map(NetworkError.forbidden(message: nil)), .unknown)
    }

    func test_conflict를_unknown으로_매핑한다() {
        XCTAssertEqual(NoticeErrorMapper.map(NetworkError.conflict(message: nil)), .unknown)
    }

    func test_429를_unknown으로_매핑한다() {
        XCTAssertEqual(
            NoticeErrorMapper.map(NetworkError.clientError(statusCode: 429, message: nil)),
            .unknown
        )
    }

    func test_serverError를_unknown으로_매핑한다() {
        XCTAssertEqual(
            NoticeErrorMapper.map(NetworkError.serverError(statusCode: 500, message: nil)),
            .unknown
        )
    }

    func test_디코딩_실패를_unknown으로_매핑한다() {
        XCTAssertEqual(NoticeErrorMapper.map(NetworkError.decodingFailed), .unknown)
        XCTAssertEqual(NoticeErrorMapper.map(NetworkError.invalidResponse), .unknown)
        XCTAssertEqual(NoticeErrorMapper.map(NetworkError.invalidURL), .unknown)
    }

    func test_이미_NoticeError면_그대로_통과시킨다() {
        XCTAssertEqual(NoticeErrorMapper.map(NoticeError.network), .network)
    }

    func test_알_수_없는_에러를_unknown으로_매핑한다() {
        struct SomeError: Error {}

        XCTAssertEqual(NoticeErrorMapper.map(SomeError()), .unknown)
    }
}
