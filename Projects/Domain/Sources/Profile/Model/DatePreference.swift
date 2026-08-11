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

/// 실내/실외
public enum IndoorOutdoor: String, Equatable, Sendable, CaseIterable {
    case indoor = "INDOOR"
    case outdoor = "OUTDOOR"
}

/// 활동 강도
public enum ActivityLevel: String, Equatable, Sendable, CaseIterable {
    case active = "ACTIVE"
    case `static` = "STATIC"
}

/// 데이트 시간대
public enum DateTime: String, Equatable, Sendable, CaseIterable {
    case day = "DAY"
    case night = "NIGHT"
}

/// 데이트 초점
public enum DateFocus: String, Equatable, Sendable, CaseIterable {
    case food = "FOOD"
    case sightseeing = "SIGHTSEEING"
}
