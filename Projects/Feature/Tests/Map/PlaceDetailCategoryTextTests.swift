import Domain
@testable import Feature
import XCTest

final class PlaceDetailCategoryTextTests: XCTestCase {
    func test_세부_분류가_없으면_붙이지_않는다() {
        XCTAssertNil(PlaceDetailCategoryText.make(detailCategory: nil, category: .cafe))
    }

    func test_세부_분류를_그대로_붙인다() {
        XCTAssertEqual(PlaceDetailCategoryText.make(detailCategory: "커피전문점", category: .cafe), "커피전문점")
    }

    func test_둘픽_분류와_같은_말이면_붙이지_않는다() {
        XCTAssertNil(PlaceDetailCategoryText.make(detailCategory: "카페", category: .cafe))
    }

    func test_띄어쓰기만_다르면_같은_말로_본다() {
        XCTAssertNil(PlaceDetailCategoryText.make(detailCategory: "생활 편의", category: .convenience))
        XCTAssertNil(PlaceDetailCategoryText.make(detailCategory: "생활편의", category: .convenience))
    }

    func test_다른_둘픽_분류의_이름이면_붙인다() {
        XCTAssertEqual(PlaceDetailCategoryText.make(detailCategory: "카페", category: .food), "카페")
    }

    func test_쉼표는_빗금으로_바꾼다() {
        XCTAssertEqual(
            PlaceDetailCategoryText.make(detailCategory: "호프,요리주점", category: .food),
            "호프/요리주점"
        )
    }
}
