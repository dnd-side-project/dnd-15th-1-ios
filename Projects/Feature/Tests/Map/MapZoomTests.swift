import CoreGraphics
import Domain
@testable import Feature
import XCTest

final class MapZoomTests: XCTestCase {

    private let anchor = Coordinate(latitude: 37.5665, longitude: 126.9780)

    /// 아이폰 14 기준. 너비 390, 시트 위 영역 844 * 0.55
    private func fit(
        _ coordinates: [Coordinate],
        viewWidth: CGFloat = 390,
        visibleHeight: CGFloat = 844 * 0.55
    ) -> Int {
        MapZoom.fit(
            coordinates: coordinates,
            anchor: anchor,
            viewWidth: viewWidth,
            visibleHeight: visibleHeight,
            maximum: MapCamera.singlePlaceZoom,
            minimum: MapZoom.lowerBound
        )
    }

    func test_장소가_하나면_한_장소용_줌을_쓴다() {
        XCTAssertEqual(fit([anchor]), MapCamera.singlePlaceZoom)
    }

    func test_목록이_비면_한_장소용_줌을_쓴다() {
        XCTAssertEqual(fit([]), MapCamera.singlePlaceZoom)
    }

    func test_멀수록_줌이_작아진다() {
        let near = Coordinate(latitude: 37.5675, longitude: 126.9790)
        let far = Coordinate(latitude: 37.7000, longitude: 127.1000)
        XCTAssertGreaterThan(fit([anchor, near]), fit([anchor, far]))
    }

    func test_하한에_닿으면_거기서_멈춘다() {
        // 지구 반대편. 어떤 줌으로도 못 담는다
        let antipode = Coordinate(latitude: -37.5665, longitude: -53.0220)
        XCTAssertEqual(fit([anchor, antipode]), MapZoom.lowerBound)
    }

    func test_상한을_넘지_않는다() {
        // 같은 자리에 겹쳐 있어도 한 장소용 줌보다 더 당기지 않는다
        XCTAssertEqual(fit([anchor, anchor, anchor]), MapCamera.singlePlaceZoom)
    }

    func test_anchor_를_중심으로_잰다() {
        // anchor 반대편으로 같은 거리만큼 떨어진 점을 더해도 결과가 같다.
        // 코스 한가운데가 아니라 anchor 가 중심이기 때문이다
        let east = Coordinate(latitude: 37.5665, longitude: 127.0780)
        let west = Coordinate(latitude: 37.5665, longitude: 126.8780)
        XCTAssertEqual(fit([anchor, east]), fit([anchor, east, west]))
    }

    func test_보이는_영역이_좁으면_줌이_작아진다() {
        let far = Coordinate(latitude: 37.6500, longitude: 126.9780)
        let wide = fit([anchor, far], visibleHeight: 844 * 0.55)
        let narrow = fit([anchor, far], visibleHeight: 844 * 0.25)
        XCTAssertLessThan(narrow, wide)
    }
}
