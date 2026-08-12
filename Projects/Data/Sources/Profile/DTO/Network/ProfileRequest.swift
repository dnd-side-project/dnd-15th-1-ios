import Foundation

// MARK: - Initialize Profile

struct InitializeMemberProfileRequestDTO: Encodable, Sendable {
    let nickname: String
    let profileIcon: Int
    let datePreferences: DatePreferencesRequestDTO?

    private enum CodingKeys: String, CodingKey {
        case nickname
        case profileIcon
        case datePreferences
    }

    // 서버가 datePreferences 를 required 로 요구한다.
    // 기본 인코딩은 nil 일 때 키를 빼므로 명시적 null 을 넣는다.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(profileIcon, forKey: .profileIcon)
        if let datePreferences {
            try container.encode(datePreferences, forKey: .datePreferences)
        } else {
            try container.encodeNil(forKey: .datePreferences)
        }
    }
}

// MARK: - Update Profile

struct UpdateMemberProfileRequestDTO: Encodable, Sendable {
    let nickname: String
    let profileIcon: Int
}

// MARK: - Date Preferences

struct DatePreferencesRequestDTO: Encodable, Sendable {
    let indoorOutdoor: String
    let activityLevel: String
    let dateTime: String
    let dateFocus: String
}
