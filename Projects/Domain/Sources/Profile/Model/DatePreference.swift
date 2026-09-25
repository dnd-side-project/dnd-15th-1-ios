import Foundation

public struct DatePreference: Equatable, Sendable {
    public let indoorOutdoor: IndoorOutdoor
    public let activityLevel: ActivityLevel
    public let dateTime: DateTime
    public let dateFocus: DateFocus

    public init(
        indoorOutdoor: IndoorOutdoor,
        activityLevel: ActivityLevel,
        dateTime: DateTime,
        dateFocus: DateFocus
    ) {
        self.indoorOutdoor = indoorOutdoor
        self.activityLevel = activityLevel
        self.dateTime = dateTime
        self.dateFocus = dateFocus
    }
}

/// 실내/실외. 서버 문자열 변환은 Data 가 맡는다
public enum IndoorOutdoor: Equatable, Sendable, CaseIterable {
    case indoor
    case outdoor
}

/// 활동 강도
public enum ActivityLevel: Equatable, Sendable, CaseIterable {
    case active
    case `static`
}

/// 데이트 시간대
public enum DateTime: Equatable, Sendable, CaseIterable {
    case day
    case night
}

/// 데이트 초점
public enum DateFocus: Equatable, Sendable, CaseIterable {
    case food
    case sightseeing
}
