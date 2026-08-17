import Foundation

// MARK: - Initialize Profile

struct InitializeMemberProfileRequestDTO: Encodable, Sendable {
    let nickname: String
    let profileIcon: Int
    /// 닉네임 단계에서는 아직 성향을 묻지 않는다. nil 이면 키 자체가 실리지 않는다.
    let datePreferences: DatePreferencesRequestDTO?
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
