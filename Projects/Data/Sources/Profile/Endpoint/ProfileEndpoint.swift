import CoreNetwork
import Foundation

enum ProfileEndpoint: APIEndpoint {
    case member
    case initializeProfile(
        nickname: String,
        profileIcon: Int,
        datePreferences: DatePreferencesRequestDTO?
    )
    case updateProfile(nickname: String, profileIcon: Int)
    case updateDatePreferences(DatePreferencesRequestDTO)

    var path: String {
        switch self {
        case .member:
            return "/api/v1/members/me"
        case .initializeProfile, .updateProfile:
            return "/api/v1/members/me/profile"
        case .updateDatePreferences:
            return "/api/v1/members/me/date-preferences"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .member:
            return .get
        case .initializeProfile:
            return .post
        case .updateProfile:
            return .patch
        case .updateDatePreferences:
            return .put
        }
    }

    var headers: [String: String] {
        [:]
    }

    var body: Data? {
        let encoder = NetworkJSONCoding.makeEncoder()
        switch self {
        case .member:
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
        }
    }
}
