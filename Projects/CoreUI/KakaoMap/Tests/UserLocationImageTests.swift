@testable import CoreKakaoMap
import XCTest

@MainActor
final class UserLocationImageTests: XCTestCase {
    func test_현재위치이미지는_배율2로_구워진다() {
        XCTAssertEqual(userLocationImage().scale, 2)
    }
}
