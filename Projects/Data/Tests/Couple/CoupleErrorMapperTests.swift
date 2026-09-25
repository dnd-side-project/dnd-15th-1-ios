import CoreNetwork
import Domain
import XCTest

@testable import Data

final class CoupleErrorMapperTests: XCTestCase {
    func test_전송_에러를_network로_매핑한다() {
        XCTAssertEqual(
            CoupleErrorMapper.map(NetworkError.transport(message: "offline")),
            .network
        )
    }

    func test_인증_실패를_unauthorized로_매핑한다() {
        XCTAssertEqual(CoupleErrorMapper.map(NetworkError.unauthorized), .unauthorized)
    }

    func test_badRequest를_invalidInviteCode로_매핑한다() {
        XCTAssertEqual(
            CoupleErrorMapper.map(NetworkError.badRequest(message: "invalid")),
            .invalidInviteCode
        )
    }

    func test_notFound를_invalidInviteCode로_매핑한다() {
        XCTAssertEqual(
            CoupleErrorMapper.map(NetworkError.notFound(message: nil)),
            .invalidInviteCode
        )
    }

    func test_conflict를_alreadyConnected로_매핑한다() {
        XCTAssertEqual(
            CoupleErrorMapper.map(NetworkError.conflict(message: "connected")),
            .alreadyConnected
        )
    }

    func test_422를_invalidInviteCode로_매핑한다() {
        XCTAssertEqual(
            CoupleErrorMapper.map(NetworkError.clientError(statusCode: 422, message: nil)),
            .invalidInviteCode
        )
    }

    func test_429를_rateLimited로_매핑한다() {
        XCTAssertEqual(
            CoupleErrorMapper.map(NetworkError.clientError(statusCode: 429, message: nil)),
            .rateLimited
        )
    }

    func test_forbidden을_unknown으로_매핑한다() {
        XCTAssertEqual(
            CoupleErrorMapper.map(NetworkError.forbidden(message: nil)),
            .unknown
        )
    }

    func test_그_외_clientError를_unknown으로_매핑한다() {
        XCTAssertEqual(
            CoupleErrorMapper.map(NetworkError.clientError(statusCode: 418, message: nil)),
            .unknown
        )
    }

    func test_serverError를_unknown으로_매핑한다() {
        XCTAssertEqual(
            CoupleErrorMapper.map(NetworkError.serverError(statusCode: 500, message: nil)),
            .unknown
        )
    }

    func test_디코딩_실패를_unknown으로_매핑한다() {
        XCTAssertEqual(CoupleErrorMapper.map(NetworkError.decodingFailed), .unknown)
        XCTAssertEqual(CoupleErrorMapper.map(NetworkError.invalidResponse), .unknown)
        XCTAssertEqual(CoupleErrorMapper.map(NetworkError.invalidURL), .unknown)
    }

    func test_이미_CoupleError면_그대로_통과시킨다() {
        XCTAssertEqual(CoupleErrorMapper.map(CoupleError.alreadyConnected), .alreadyConnected)
    }

    func test_알_수_없는_에러를_unknown으로_매핑한다() {
        struct SomeError: Error {}

        XCTAssertEqual(CoupleErrorMapper.map(SomeError()), .unknown)
    }
}
