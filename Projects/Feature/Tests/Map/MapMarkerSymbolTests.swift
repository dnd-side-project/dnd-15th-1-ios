import Domain
@testable import Feature
import XCTest

@MainActor
final class MapMarkerSymbolTests: XCTestCase {
    func test_마커이미지는_배율2로_구워진다() {
        let kinds: [MapMarker.Kind] = [
            .place,
            .numbered(1),
            .category(.cafe),
            .selected,
            .candidate,
        ]

        for kind in kinds {
            XCTAssertEqual(
                MapMarkerSymbol.image(for: kind).scale,
                2,
                "\(kind) 마커는 SDK 보정을 상쇄하려고 배율 2로 구워야 한다"
            )
        }
    }

    func test_현재위치이미지는_배율2로_구워진다() {
        XCTAssertEqual(MapMarkerSymbol.userLocationImage().scale, 2)
    }
}
