import CoreNetwork
import XCTest

final class NetworkJSONCodingTests: XCTestCase {
    func test_서버_날짜_형식_여섯_가지를_읽고_날짜가_아니면_nil을_준다() {
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08T13:03:22"))
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08"))
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08T13:03:22.727Z"))
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08T13:03:22Z"))
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08T13:03:22.727+09:00"))
        XCTAssertNotNil(NetworkJSONCoding.parseDate("2026-08-08T13:03:22+09:00"))
        XCTAssertNil(NetworkJSONCoding.parseDate("not-a-date"))
    }

    func test_소수점_초와_Z가_붙은_서버_날짜를_디코딩한다() throws {
        struct Payload: Decodable {
            let lastRejoinedAt: Date
        }

        let json = Data(#"{"lastRejoinedAt":"2026-08-08T13:03:22.727Z"}"#.utf8)
        let payload = try NetworkJSONCoding.makeDecoder().decode(Payload.self, from: json)
        XCTAssertEqual(
            payload.lastRejoinedAt.timeIntervalSince1970,
            1786194202.727,
            accuracy: 0.001
        )
    }
}
