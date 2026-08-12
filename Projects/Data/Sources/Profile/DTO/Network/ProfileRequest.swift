import Foundation

// MARK: - Initialize Profile

struct InitializeMemberProfileRequestDTO: Encodable, Sendable {
    let nickname: String
    let profileIcon: Int
    // 서버가 required 로 받고 null 을 거부하므로 항상 객체를 싣는다.
    let datePreferences: DatePreferencesRequestDTO
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

    /// 빈 문자열 4축은 "성향 미설정" 을 뜻한다. 첫 온보딩에서 성향을 아직 받지 않았을 때 쓴다.
    static let empty = DatePreferencesRequestDTO(
        indoorOutdoor: "",
        activityLevel: "",
        dateTime: "",
        dateFocus: ""
    )
}
