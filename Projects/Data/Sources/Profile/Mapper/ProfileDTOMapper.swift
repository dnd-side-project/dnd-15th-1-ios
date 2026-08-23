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
            let indoorOutdoor = dto.indoorOutdoor.flatMap(IndoorOutdoor.init(rawValue:)),
            let activityLevel = dto.activityLevel.flatMap(ActivityLevel.init(rawValue:)),
            let dateTime = dto.dateTime.flatMap(DateTime.init(rawValue:)),
            let dateFocus = dto.dateFocus.flatMap(DateFocus.init(rawValue:))
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

    static func toDomain(_ dto: NotificationSettingsResponseDTO) -> NotificationSettings {
        NotificationSettings(
            contentSavedEnabled: dto.contentSavedEnabled,
            dateScheduleEnabled: dto.dateScheduleEnabled,
            marketingEnabled: dto.marketingEnabled
        )
    }

    static func toRequest(_ preference: DatePreference) -> DatePreferencesRequestDTO {
        DatePreferencesRequestDTO(
            indoorOutdoor: preference.indoorOutdoor.rawValue,
            activityLevel: preference.activityLevel.rawValue,
            dateTime: preference.dateTime.rawValue,
            dateFocus: preference.dateFocus.rawValue
        )
    }

    private static let defaultIconID = 1
}
