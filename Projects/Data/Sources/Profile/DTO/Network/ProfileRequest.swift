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

    /// 프로필 최초 생성(POST /members/me/profile)에만 싣는 임시 값이다.
    ///
    /// 서버가 4축을 전부 필수 enum 으로 요구해서, 성향을 아직 묻기도 전인 닉네임 단계에서
    /// 보낼 값이 필요하다. 빈 문자열을 보내면 400 INVALID_INPUT 으로 거부당한다.
    /// 그래서 각 축의 첫 enum 값을 대신 채운다. 사용자가 고른 값이 아니다.
    ///
    /// 데이트 유형 화면에서 저장하면 PUT /members/me/date-preferences 로 덮어써지지만,
    /// 건너뛰면 이 값이 서버에 그대로 남는다. 남은 placeholder 가 추천에 쓰이면
    /// 사용자는 고른 적 없는 취향으로 추천을 받는다.
    /// 서버가 빈 값 또는 null 을 받도록 바뀔 예정이고, 그때 이 상수와 호출부를 지운다.
    static let onboardingPlaceholder = DatePreferencesRequestDTO(
        indoorOutdoor: "INDOOR",
        activityLevel: "ACTIVE",
        dateTime: "DAY",
        dateFocus: "FOOD"
    )
}
