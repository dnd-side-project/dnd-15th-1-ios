import CoreNetwork
import Domain
import XCTest

@testable import Data

final class NotificationErrorMapperTests: XCTestCase {
    func test_transport는_network다() {
        XCTAssertEqual(NotificationErrorMapper.map(NetworkError.transport(message: "timeout")), .network)
    }

    func test_401은_unauthorized다() {
        XCTAssertEqual(NotificationErrorMapper.map(NetworkError.unauthorized), .unauthorized)
    }

    func test_400은_invalidRequest다() {
        XCTAssertEqual(NotificationErrorMapper.map(NetworkError.badRequest(message: nil)), .invalidRequest)
    }

    func test_409는_registrationConflict다() {
        XCTAssertEqual(NotificationErrorMapper.map(NetworkError.conflict(message: nil)), .registrationConflict)
    }

    func test_503은_providerUnavailable다() {
        XCTAssertEqual(
            NotificationErrorMapper.map(NetworkError.serverError(statusCode: 503, message: nil)),
            .providerUnavailable
        )
    }

    func test_500은_unknown이다() {
        XCTAssertEqual(
            NotificationErrorMapper.map(NetworkError.serverError(statusCode: 500, message: nil)),
            .unknown
        )
    }

    func test_이미_NotificationError면_그대로_돌려준다() {
        XCTAssertEqual(NotificationErrorMapper.map(NotificationError.registrationConflict), .registrationConflict)
    }
}
