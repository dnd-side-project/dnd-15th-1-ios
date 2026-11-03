@testable import Feature
import XCTest

final class PlacePhotoPagingTests: XCTestCase {
    func test_사진이_1장이면_점도_화살표도_없다() {
        XCTAssertEqual(PlacePhotoPaging.dots(count: 1, current: 0), [])
        XCTAssertEqual(
            PlacePhotoPaging.arrows(count: 1, current: 0),
            PlacePhotoArrows(showsPrevious: false, showsNext: false)
        )
    }

    func test_사진이_없으면_점이_없다() {
        XCTAssertEqual(PlacePhotoPaging.dots(count: 0, current: 0), [])
    }

    func test_5장_이하면_점을_다_그리고_작은_점이_없다() {
        let dots = PlacePhotoPaging.dots(count: 5, current: 3)

        XCTAssertEqual(dots.map(\.index), [0, 1, 2, 3, 4])
        XCTAssertEqual(dots.filter(\.isCurrent).map(\.index), [3])
        XCTAssertTrue(dots.allSatisfy { !$0.isSmall })
    }

    func test_넘치면_첫_사진에서는_오른쪽_끝_점만_작다() {
        let dots = PlacePhotoPaging.dots(count: 8, current: 0)

        XCTAssertEqual(dots.map(\.index), [0, 1, 2, 3, 4])
        XCTAssertEqual(dots.filter(\.isSmall).map(\.index), [4])
    }

    func test_넘치면_지금_사진이_창_가운데고_양쪽_끝_점이_작다() {
        XCTAssertEqual(PlacePhotoPaging.dots(count: 8, current: 4), [
            PlacePhotoDot(index: 2, isCurrent: false, isSmall: true),
            PlacePhotoDot(index: 3, isCurrent: false, isSmall: false),
            PlacePhotoDot(index: 4, isCurrent: true, isSmall: false),
            PlacePhotoDot(index: 5, isCurrent: false, isSmall: false),
            PlacePhotoDot(index: 6, isCurrent: false, isSmall: true),
        ])
    }

    func test_넘치면_마지막_사진에서는_왼쪽_끝_점만_작다() {
        let dots = PlacePhotoPaging.dots(count: 8, current: 7)

        XCTAssertEqual(dots.map(\.index), [3, 4, 5, 6, 7])
        XCTAssertEqual(dots.filter(\.isSmall).map(\.index), [3])
    }

    func test_창이_끝에_닿으면_그쪽_끝_점은_작지_않다() {
        let dots = PlacePhotoPaging.dots(count: 6, current: 3)

        XCTAssertEqual(dots.map(\.index), [1, 2, 3, 4, 5])
        XCTAssertEqual(dots.filter(\.isSmall).map(\.index), [1])
    }

    func test_화살표는_첫_사진에서_오른쪽만_마지막에서_왼쪽만_가운데서_양쪽이다() {
        XCTAssertEqual(
            PlacePhotoPaging.arrows(count: 3, current: 0),
            PlacePhotoArrows(showsPrevious: false, showsNext: true)
        )
        XCTAssertEqual(
            PlacePhotoPaging.arrows(count: 3, current: 2),
            PlacePhotoArrows(showsPrevious: true, showsNext: false)
        )
        XCTAssertEqual(
            PlacePhotoPaging.arrows(count: 3, current: 1),
            PlacePhotoArrows(showsPrevious: true, showsNext: true)
        )
    }
}
