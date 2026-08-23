import Foundation

// MARK: - Initialized Profile

struct InitializedMemberProfileResponseDTO: Decodable, Equatable, Sendable {
    let nickname: String
    let profileIcon: Int
    let datePreferences: MemberDatePreferencesResponseDTO?
    let connectionCode: String?
    let shareUrl: String?
}

// MARK: - Updated Profile

struct UpdatedMemberProfileResponseDTO: Decodable, Equatable, Sendable {
    let nickname: String
    let profileIcon: Int
}

// MARK: - Date Preferences

struct MemberDatePreferencesResponseDTO: Decodable, Equatable, Sendable {
    let indoorOutdoor: String?
    let activityLevel: String?
    let dateTime: String?
    let dateFocus: String?
}

// MARK: - Member

struct MemberResponseDTO: Decodable, Equatable, Sendable {
    let memberId: Int?
    let onboardingCompleted: Bool
    let nickname: String?
    let profileIcon: Int?
    let datePreferences: MemberDatePreferencesResponseDTO?
}

// MARK: - Notification Settings

struct NotificationSettingsResponseDTO: Decodable, Equatable, Sendable {
    let contentSavedEnabled: Bool
    let dateScheduleEnabled: Bool
    let marketingEnabled: Bool
    let marketingConsentVersion: String?
    let availableMarketingConsentVersion: String?
}
