import Domain
import Foundation

enum ProfileDTOMapper {
    static func toDomain(_ dto: InitializedMemberProfileResponseDTO) -> UserProfile {
        UserProfile(
            nickname: dto.nickname,
            iconID: dto.profileIcon,
            datePreference: toDatePreference(dto.datePreferences)
        )
    }

    static func toDomain(
        _ dto: UpdatedMemberProfileResponseDTO,
        datePreference: DatePreference?
    ) -> UserProfile {
        UserProfile(
            nickname: dto.nickname,
            iconID: dto.profileIcon,
            datePreference: datePreference
        )
    }

    static func toDomain(_ dto: MemberResponseDTO) -> UserProfile? {
        guard let nickname = dto.nickname else {
            return nil
        }
        return UserProfile(
            nickname: nickname,
            iconID: dto.profileIcon ?? defaultIconID,
            datePreference: toDatePreference(dto.datePreferences)
        )
    }

    /// 4축이 모두 파싱될 때만 성향을 만든다. 부분 성향은 Domain 에 없는 상태다.
    static func toDatePreference(_ dto: MemberDatePreferencesResponseDTO?) -> DatePreference? {
        guard
            let dto,
            let indoorOutdoor = dto.indoorOutdoor.flatMap(parseIndoorOutdoor),
            let activityLevel = dto.activityLevel.flatMap(parseActivityLevel),
            let dateTime = dto.dateTime.flatMap(parseDateTime),
            let dateFocus = dto.dateFocus.flatMap(parseDateFocus)
        else {
            return nil
        }
        return DatePreference(
            indoorOutdoor: indoorOutdoor,
            activityLevel: activityLevel,
            dateTime: dateTime,
            dateFocus: dateFocus
        )
    }

    static func toRequest(_ preference: DatePreference) -> DatePreferencesRequestDTO {
        DatePreferencesRequestDTO(
            indoorOutdoor: serverValue(preference.indoorOutdoor),
            activityLevel: serverValue(preference.activityLevel),
            dateTime: serverValue(preference.dateTime),
            dateFocus: serverValue(preference.dateFocus)
        )
    }

    private static let defaultIconID = 1

    // MARK: - 성향 서버 문자열

    // 모르는 값은 nil 이다. 한 축이라도 모르면 성향 전체를 없는 것으로 본다
    private static func parseIndoorOutdoor(_ raw: String) -> IndoorOutdoor? {
        switch raw {
        case "INDOOR": return .indoor
        case "OUTDOOR": return .outdoor
        default: return nil
        }
    }

    private static func parseActivityLevel(_ raw: String) -> ActivityLevel? {
        switch raw {
        case "ACTIVE": return .active
        case "STATIC": return .`static`
        default: return nil
        }
    }

    private static func parseDateTime(_ raw: String) -> DateTime? {
        switch raw {
        case "DAY": return .day
        case "NIGHT": return .night
        default: return nil
        }
    }

    private static func parseDateFocus(_ raw: String) -> DateFocus? {
        switch raw {
        case "FOOD": return .food
        case "SIGHTSEEING": return .sightseeing
        default: return nil
        }
    }

    private static func serverValue(_ value: IndoorOutdoor) -> String {
        switch value {
        case .indoor: return "INDOOR"
        case .outdoor: return "OUTDOOR"
        }
    }

    private static func serverValue(_ value: ActivityLevel) -> String {
        switch value {
        case .active: return "ACTIVE"
        case .`static`: return "STATIC"
        }
    }

    private static func serverValue(_ value: DateTime) -> String {
        switch value {
        case .day: return "DAY"
        case .night: return "NIGHT"
        }
    }

    private static func serverValue(_ value: DateFocus) -> String {
        switch value {
        case .food: return "FOOD"
        case .sightseeing: return "SIGHTSEEING"
        }
    }
}
