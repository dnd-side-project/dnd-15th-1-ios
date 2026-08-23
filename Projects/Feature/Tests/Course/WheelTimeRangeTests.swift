import Feature
import XCTest

final class WheelTimeRangeTests: XCTestCase {

    private let minuteStep = 5
    private let minimumPM = DateComponents(hour: 22, minute: 5)
    private let minimumAM = DateComponents(hour: 10, minute: 15)
    private let allHours = [12] + Array(1...11)
    private let allMinutes = Array(stride(from: 0, to: 60, by: 5))

    func test_하한이_오후면_오전_열이_빠진다() {
        let range = WheelTimeRange(minuteStep: minuteStep, minimum: minimumPM)

        XCTAssertEqual(range.periods, [.pm])
    }

    func test_하한과_같은_오전오후면_시가_하한의_시부터_시작한다() {
        let range = WheelTimeRange(minuteStep: minuteStep, minimum: minimumPM)

        XCTAssertEqual(range.hours(period: .pm), [10, 11])
    }

    func test_하한보다_뒤_오전오후를_고르면_시가_12시부터_시작한다() {
        let range = WheelTimeRange(minuteStep: minuteStep, minimum: minimumAM)

        XCTAssertEqual(range.hours(period: .pm), allHours)
    }

    func test_하한과_같은_시면_분이_하한의_분부터_시작한다() {
        let range = WheelTimeRange(minuteStep: minuteStep, minimum: minimumPM)

        XCTAssertEqual(range.minutes(period: .pm, hour: 10), Array(stride(from: 5, to: 60, by: 5)))
    }

    func test_하한보다_뒤_시를_고르면_분이_0분부터_시작한다() {
        let range = WheelTimeRange(minuteStep: minuteStep, minimum: minimumPM)

        XCTAssertEqual(range.minutes(period: .pm, hour: 11), allMinutes)
    }

    func test_하한_밖_시각은_하한으로_끌어올려진다() {
        let range = WheelTimeRange(minuteStep: minuteStep, minimum: minimumPM)
        let resolved = range.resolved(DateComponents(hour: 9, minute: 0))

        XCTAssertEqual(resolved.hour, 22)
        XCTAssertEqual(resolved.minute, 5)
    }

    func test_하한이_없으면_오전오후시분_열이_제한_없이_나온다() {
        let range = WheelTimeRange(minuteStep: minuteStep, minimum: nil)

        XCTAssertEqual(range.periods, [.am, .pm])
        XCTAssertEqual(range.hours(period: .am), allHours)
        XCTAssertEqual(range.minutes(period: .am, hour: 10), allMinutes)
    }
}
