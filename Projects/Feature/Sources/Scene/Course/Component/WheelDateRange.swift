import Foundation

// MARK: - WheelDateRange

/// 날짜 굴림판 세 열의 보이는 범위와, 고른 값이 그 밖으로 나갔을 때 되돌릴 자리를 계산한다.
///
/// `minimum` 이 있으면 그보다 앞선 연·월·일은 목록에서 빠진다. `nil` 이면 `yearRange` 와 달력 일수만 본다.
public struct WheelDateRange: Equatable, Sendable {

    public let yearRange: ClosedRange<Int>
    public let minimum: DateComponents?

    public init(yearRange: ClosedRange<Int>, minimum: DateComponents? = nil) {
        self.yearRange = yearRange
        self.minimum = minimum
    }

    public var years: [Int] {
        Array(yearLowerBound ... yearRange.upperBound)
    }

    public func months(year: Int) -> [Int] {
        Array(monthLowerBound(year: year) ... 12)
    }

    public func days(year: Int, month: Int) -> [Int] {
        let last = dayCount(year: year, month: month)
        let first = min(dayLowerBound(year: year, month: month), last)
        return Array(first ... last)
    }

    public func resolved(_ selection: DateComponents) -> DateComponents {
        let year = min(max(selection.year ?? yearLowerBound, yearLowerBound), yearRange.upperBound)
        let monthStart = monthLowerBound(year: year)
        let month = min(max(selection.month ?? monthStart, monthStart), 12)
        let lastDay = dayCount(year: year, month: month)
        let dayStart = dayLowerBound(year: year, month: month)
        // 하한으로 올린 뒤 그 달 일수로 내린다. 나중에 올리면 그 달에 없는 날이 될 수 있다.
        let day = min(max(selection.day ?? dayStart, dayStart), lastDay)

        var components = selection
        components.year = year
        components.month = month
        components.day = day
        return components
    }
}

// MARK: - Bound

private extension WheelDateRange {

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.autoupdatingCurrent
        return calendar
    }()

    var yearLowerBound: Int {
        guard let year = minimum?.year else { return yearRange.lowerBound }
        return min(max(year, yearRange.lowerBound), yearRange.upperBound)
    }

    func monthLowerBound(year: Int) -> Int {
        guard let minimumYear = minimum?.year, year == minimumYear else { return 1 }
        let month = minimum?.month ?? 1
        return min(max(month, 1), 12)
    }

    func dayLowerBound(year: Int, month: Int) -> Int {
        guard
            let minimumYear = minimum?.year,
            let minimumMonth = minimum?.month,
            year == minimumYear,
            month == minimumMonth
        else { return 1 }
        return max(minimum?.day ?? 1, 1)
    }

    func dayCount(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard
            let date = Self.calendar.date(from: components),
            let dayRange = Self.calendar.range(of: .day, in: .month, for: date)
        else {
            return 31
        }

        return dayRange.count
    }
}
