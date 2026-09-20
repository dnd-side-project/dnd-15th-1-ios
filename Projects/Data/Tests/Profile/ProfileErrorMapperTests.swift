import CoreNetwork
import Domain
import XCTest

@testable import Data

final class ProfileErrorMapperTests: XCTestCase {
    func test_전송_에러를_network로_매핑한다() {
        XCTAssertEqual(
            ProfileErrorMapper.map(NetworkError.transport(message: "offline")),
            .network
        )
    }

    func test_인증_실패를_unauthorized로_매핑한다() {
        XCTAssertEqual(ProfileErrorMapper.map(NetworkError.unauthorized), .unauthorized)
    }

    func test_badRequest를_invalidNickname으로_매핑한다() {
        XCTAssertEqual(
            ProfileErrorMapper.map(NetworkError.badRequest(message: "invalid")),
            .invalidNickname
        )
    }

    func test_conflict를_invalidNickname으로_매핑한다() {
        XCTAssertEqual(
            ProfileErrorMapper.map(NetworkError.conflict(message: "duplicated")),
            .invalidNickname
        )
    }

    func test_422를_invalidNickname으로_매핑한다() {
        XCTAssertEqual(
            ProfileErrorMapper.map(NetworkError.clientError(statusCode: 422, message: nil)),
            .invalidNickname
        )
    }

    func test_429를_unknown으로_매핑한다() {
        XCTAssertEqual(
            ProfileErrorMapper.map(NetworkError.clientError(statusCode: 429, message: nil)),
            .unknown
        )
    }

    func test_notFound를_unknown으로_매핑한다() {
        XCTAssertEqual(
            ProfileErrorMapper.map(NetworkError.notFound(message: nil)),
            .unknown
        )
    }

    func test_forbidden을_unknown으로_매핑한다() {
        XCTAssertEqual(
            ProfileErrorMapper.map(NetworkError.forbidden(message: nil)),
            .unknown
        )
    }

    func test_serverError를_unknown으로_매핑한다() {
        XCTAssertEqual(
            ProfileErrorMapper.map(NetworkError.serverError(statusCode: 500, message: nil)),
            .unknown
        )
    }

    func test_디코딩_실패를_unknown으로_매핑한다() {
        XCTAssertEqual(ProfileErrorMapper.map(NetworkError.decodingFailed), .unknown)
        XCTAssertEqual(ProfileErrorMapper.map(NetworkError.invalidResponse), .unknown)
        XCTAssertEqual(ProfileErrorMapper.map(NetworkError.invalidURL), .unknown)
    }

    func test_이미_ProfileError면_그대로_통과시킨다() {
        XCTAssertEqual(ProfileErrorMapper.map(ProfileError.invalidNickname), .invalidNickname)
    }

    func test_알_수_없는_에러를_unknown으로_매핑한다() {
        struct SomeError: Error {}

        XCTAssertEqual(ProfileErrorMapper.map(SomeError()), .unknown)
    }
}
