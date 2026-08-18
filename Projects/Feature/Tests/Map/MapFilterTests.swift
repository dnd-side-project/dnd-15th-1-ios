import Domain
import Feature
import XCTest

final class PlaceOwnershipFilterTests: XCTestCase {
    func test_드롭다운_차례가_세종류를_빠짐없이_담는다() {
        XCTAssertEqual(Set(PlaceOwnership.mapDisplayOrder), Set(PlaceOwnership.allCases))
        XCTAssertEqual(PlaceOwnership.mapDisplayOrder.first, .together)
    }

    func test_함께저장한은_세종류를_다_통과시킨다() {
        for ownership in PlaceOwnership.allCases {
            XCTAssertTrue(PlaceOwnership.together.matches(ownership), "\(ownership) 가 걸러졌다")
        }
    }

    func test_내가저장한은_둘다저장한것도_담는다() {
        XCTAssertTrue(PlaceOwnership.mine.matches(.mine))
        XCTAssertTrue(PlaceOwnership.mine.matches(.together))
        XCTAssertFalse(PlaceOwnership.mine.matches(.partner))
    }

    func test_상대가저장한은_둘다저장한것도_담는다() {
        XCTAssertTrue(PlaceOwnership.partner.matches(.partner))
        XCTAssertTrue(PlaceOwnership.partner.matches(.together))
        XCTAssertFalse(PlaceOwnership.partner.matches(.mine))
    }

    func test_표시이름과_값이_서로_되돌아간다() {
        for filter in PlaceOwnership.mapDisplayOrder {
            XCTAssertEqual(PlaceOwnership.fromDisplayName(filter.displayName), filter)
        }
        XCTAssertEqual(PlaceOwnership.together.displayName, "함께 저장한")
        XCTAssertNil(PlaceOwnership.fromDisplayName("지역 선택"))
    }
}

final class MapCategoryTests: XCTestCase {
    func test_칩차례가_일곱종을_빠짐없이_담는다() {
        XCTAssertEqual(PlaceCategory.mapDisplayOrder.count, PlaceCategory.allCases.count)
        XCTAssertEqual(Set(PlaceCategory.mapDisplayOrder), Set(PlaceCategory.allCases))
    }

    func test_앞_네_칩은_시안_차례다() {
        XCTAssertEqual(
            Array(PlaceCategory.mapDisplayOrder.prefix(4)),
            [.food, .cafe, .activity, .shopping]
        )
    }

    func test_표시이름과_값이_서로_되돌아간다() {
        for category in PlaceCategory.allCases {
            XCTAssertEqual(PlaceCategory.fromDisplayName(category.displayName), category)
        }
        XCTAssertEqual(PlaceCategory.food.displayName, "맛집")
        XCTAssertNil(PlaceCategory.fromDisplayName("없는 이름"))
    }
}
