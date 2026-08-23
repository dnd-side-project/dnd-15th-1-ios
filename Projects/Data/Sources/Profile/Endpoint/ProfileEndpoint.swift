import CoreNetwork
import Foundation

enum ProfileEndpoint: APIEndpoint {
    case member
    case withdraw
    case notificationSettings
    case updateNotificationSettings(NotificationSettingsRequestDTO)
    case initializeProfile(
        nickname: String,
        profileIcon: Int,
        datePreferences: DatePreferencesRequestDTO?
    )
    case updateProfile(nickname: String, profileIcon: Int)
    case updateDatePreferences(DatePreferencesRequestDTO)

    var path: String {
        switch self {
        case .member, .withdraw:
            return "/api/v1/members/me"
        case .notificationSettings, .updateNotificationSettings:
            return "/api/v1/members/me/notification-settings"
        case .initializeProfile, .updateProfile:
            return "/api/v1/members/me/profile"
        case .updateDatePreferences:
            return "/api/v1/members/me/date-preferences"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .member, .notificationSettings:
            return .get
        case .initializeProfile:
            return .post
        case .updateProfile:
            return .patch
        case .updateDatePreferences, .updateNotificationSettings:
            return .put
        case .withdraw:
            return .delete
        }
    }

    var headers: [String: String] {
        [:]
    }

    var body: Data? {
        let encoder = NetworkJSONCoding.makeEncoder()
        switch self {
        case .member, .notificationSettings, .withdraw:
            return nil
        case let .initializeProfile(nickname, profileIcon, datePreferences):
            return try? encoder.encode(
                InitializeMemberProfileRequestDTO(
                    nickname: nickname,
                    profileIcon: profileIcon,
                    datePreferences: datePreferences
                )
            )
        case let .updateProfile(nickname, profileIcon):
            return try? encoder.encode(
                UpdateMemberProfileRequestDTO(
                    nickname: nickname,
                    profileIcon: profileIcon
                )
            )
        case let .updateDatePreferences(preferences):
            return try? encoder.encode(preferences)
        case let .updateNotificationSettings(settings):
            return try? encoder.encode(settings)
        }
    }
}
