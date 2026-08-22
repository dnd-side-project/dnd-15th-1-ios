import Feature
import XCTest

final class WheelDateRangeTests: XCTestCase {

    private let yearRange = 2024 ... 2034
    private let minimum = DateComponents(year: 2026, month: 8, day: 25)

    func test_하한이_있으면_연이_하한의_해부터_시작한다() {
        let range = WheelDateRange(yearRange: yearRange, minimum: minimum)

        XCTAssertEqual(range.years, Array(2026 ... 2034))
    }

    func test_하한과_같은_해를_고르면_월이_하한의_달부터_시작한다() {
        let range = WheelDateRange(yearRange: yearRange, minimum: minimum)

        XCTAssertEqual(range.months(year: 2026), Array(8 ... 12))
    }

    func test_하한보다_뒤_해를_고르면_월이_1월부터_시작한다() {
        let range = WheelDateRange(yearRange: yearRange, minimum: minimum)

        XCTAssertEqual(range.months(year: 2027), Array(1 ... 12))
    }

    func test_하한과_같은_해같은_달이면_일이_하한의_날부터_시작한다() {
        let range = WheelDateRange(yearRange: yearRange, minimum: minimum)

        XCTAssertEqual(range.days(year: 2026, month: 8), Array(25 ... 31))
    }

    func test_하한_밖_날짜는_하한으로_끌어올려진다() {
        let range = WheelDateRange(yearRange: yearRange, minimum: minimum)
        let resolved = range.resolved(DateComponents(year: 2026, month: 8, day: 20))

        XCTAssertEqual(resolved.year, 2026)
        XCTAssertEqual(resolved.month, 8)
        XCTAssertEqual(resolved.day, 25)
    }

    func test_하한이_없으면_연월일_열이_제한_없이_나온다() {
        let range = WheelDateRange(yearRange: yearRange, minimum: nil)

        XCTAssertEqual(range.years, Array(2024 ... 2034))
        XCTAssertEqual(range.months(year: 2026), Array(1 ... 12))
        XCTAssertEqual(range.days(year: 2026, month: 8), Array(1 ... 31))
    }

    func test_달이_짧아지면_일이_그_달_마지막_날로_내려앉는다() {
        let range = WheelDateRange(yearRange: yearRange, minimum: nil)
        let resolved = range.resolved(DateComponents(year: 2026, month: 2, day: 31))

        XCTAssertEqual(resolved.year, 2026)
        XCTAssertEqual(resolved.month, 2)
        XCTAssertEqual(resolved.day, 28)
    }

    func test_윤년_2월은_일이_29일까지_나온다() {
        let range = WheelDateRange(yearRange: yearRange, minimum: nil)

        XCTAssertEqual(range.days(year: 2028, month: 2), Array(1 ... 29))
    }
}
