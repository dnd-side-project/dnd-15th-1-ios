import Foundation

// MARK: - WheelTimeRange

/// 시각 굴림판 세 열의 보이는 범위와, 고른 값이 그 밖으로 나갔을 때 되돌릴 자리를 계산한다.
///
/// `minimum` 이 있으면 그보다 앞선 오전·오후·시·분은 목록에서 빠진다. `nil` 이면 오전·오후와 분 간격만 본다.
/// 시 열은 12시간제(`[12] + 1...11`)다. `resolved` 의 `hour` 는 0...23 이다.
public struct WheelTimeRange: Equatable, Sendable {

    public let minuteStep: Int
    public let minimum: DateComponents?

    public init(minuteStep: Int, minimum: DateComponents? = nil) {
        self.minuteStep = minuteStep
        self.minimum = minimum
    }

    public var periods: [DayPeriod] {
        guard let hour = clampedHour(minimum?.hour) else { return DayPeriod.allCases }
        return hour < 12 ? DayPeriod.allCases : [.pm]
    }

    public func hours(period: DayPeriod) -> [Int] {
        let all = Self.hours
        guard let minHour24 = clampedHour(minimum?.hour) else { return all }
        let minPeriod = minHour24 < 12 ? DayPeriod.am : .pm
        guard period == minPeriod else { return all }
        let minHour12 = hour12(minHour24)
        guard let index = all.firstIndex(of: minHour12) else { return all }
        return Array(all[index...])
    }

    public func minutes(period: DayPeriod, hour: Int) -> [Int] {
        let start = minuteLowerBound(hour24: hour24(period: period, hour12: hour))
        return Array(stride(from: 0, to: 60, by: resolvedStep)).filter { $0 >= start }
    }

    public func resolved(_ selection: DateComponents) -> DateComponents {
        let hourStart = clampedHour(minimum?.hour) ?? 0
        let hour = min(max(selection.hour ?? hourStart, hourStart), 23)
        let minuteStart = minuteLowerBound(hour24: hour)
        let minute = snappedMinute(selection.minute ?? minuteStart, lowerBound: minuteStart)

        var components = selection
        components.hour = hour
        components.minute = minute
        return components
    }
}

// MARK: - Bound

private extension WheelTimeRange {

    static let hours = [12] + Array(1...11)

    var resolvedStep: Int {
        (1...60).contains(minuteStep) ? minuteStep : 1
    }

    func clampedHour(_ hour: Int?) -> Int? {
        guard let hour else { return nil }
        return min(max(hour, 0), 23)
    }

    func hour12(_ hour24: Int) -> Int {
        let hour = hour24 % 12
        return hour == 0 ? 12 : hour
    }

    func hour24(period: DayPeriod, hour12: Int) -> Int {
        (hour12 % 12) + (period == .pm ? 12 : 0)
    }

    func minuteLowerBound(hour24: Int) -> Int {
        guard let minHour = clampedHour(minimum?.hour), hour24 == minHour else { return 0 }
        return min(max(minimum?.minute ?? 0, 0), 59)
    }

    func snappedMinute(_ minute: Int, lowerBound: Int) -> Int {
        let allowed = Array(stride(from: 0, to: 60, by: resolvedStep)).filter { $0 >= lowerBound }
        let clamped = min(max(minute, lowerBound), 59)
        return allowed.last(where: { $0 <= clamped }) ?? allowed.first ?? lowerBound
    }
}
