import Domain
import XCTest

final class DateCourseTitleTests: XCTestCase {

    func test_날짜를_시안_형식_데이트명으로_만든다() {
        let title = DateCourseTitle.make(
            date: DateComponents(year: 2026, month: 8, day: 5)
        )

        XCTAssertEqual(title, "26.08.05 데이트")
    }

    func test_한자리_월일도_두자리로_채운다() {
        let title = DateCourseTitle.make(
            date: DateComponents(year: 2026, month: 1, day: 9)
        )

        XCTAssertEqual(title, "26.01.09 데이트")
    }

    func test_연월일이_비면_빈_데이트명을_만들지_않는다() {
        let title = DateCourseTitle.make(date: DateComponents())

        XCTAssertEqual(title, "데이트")
    }
}
