@testable import CoreKakaoMap
import XCTest

@MainActor
final class UserLocationImageTests: XCTestCase {
    func test_현재위치이미지는_배율2로_구워진다() {
        XCTAssertEqual(userLocationImage().scale, 2)
    }

    func test_현재위치이미지는_40_정사각형이다() {
        XCTAssertEqual(userLocationImage().size, CGSize(width: 40, height: 40))
    }
}
