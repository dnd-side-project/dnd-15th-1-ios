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

    func test_잘못된_요청과_충돌은_invalidNickname으로_매핑한다() {
        let errors: [NetworkError] = [
            .badRequest(message: "invalid"),
            .conflict(message: "duplicated"),
        ]

        for error in errors {
            XCTAssertEqual(ProfileErrorMapper.map(error), .invalidNickname, "\(error)")
        }
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

    func test_권한_없음과_못찾음과_서버_에러는_unknown으로_매핑한다() {
        let errors: [NetworkError] = [
            .notFound(message: nil),
            .forbidden(message: nil),
            .serverError(statusCode: 500, message: nil),
        ]

        for error in errors {
            XCTAssertEqual(ProfileErrorMapper.map(error), .unknown, "\(error)")
        }
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
