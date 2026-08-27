@testable import Feature
import XCTest

final class MapCameraAnimationTests: XCTestCase {

    func test_카메라_이동은_들어올린다() {
        XCTAssertTrue(MapCameraMove.autoElevation)
    }

    func test_카메라_이동_시간은_150밀리초다() {
        XCTAssertEqual(MapCameraMove.durationInMillis, 150)
    }
}
