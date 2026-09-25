import Domain
import XCTest

@testable import Data

final class NotificationDTOMapperTests: XCTestCase {
    func test_플랫폼과_공급자는_고정값이다() {
        let request = NotificationDTOMapper.toRequest(token: "fcm-token", appVersion: "1.0.0")

        XCTAssertEqual(request.platform, "IOS")
        XCTAssertEqual(request.provider, "FCM")
        XCTAssertEqual(request.providerRegistrationId, "fcm-token")
        XCTAssertEqual(request.appVersion, "1.0.0")
    }

    func test_앱_버전이_없으면_nil로_둔다() {
        let request = NotificationDTOMapper.toRequest(token: "fcm-token", appVersion: nil)

        XCTAssertNil(request.appVersion)
    }
}
