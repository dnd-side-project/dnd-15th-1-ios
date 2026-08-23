@testable import Feature
import XCTest

final class MapCameraAnimationTests: XCTestCase {

    func test_카메라_이동은_들어올리지_않는다() {
        XCTAssertFalse(MapCameraMove.autoElevation)
    }

    func test_카메라_이동_시간은_250밀리초다() {
        XCTAssertEqual(MapCameraMove.durationInMillis, 250)
    }
}
