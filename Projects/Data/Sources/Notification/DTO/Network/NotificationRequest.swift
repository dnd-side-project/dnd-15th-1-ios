import Foundation

// MARK: - Push Device

struct NotificationDeviceRequestDTO: Encodable, Sendable, Equatable {
    let platform: String
    let provider: String
    let providerRegistrationId: String
    /// 없으면 키 자체가 실리지 않는다.
    let appVersion: String?
}

// MARK: - Notification Settings

struct NotificationSettingsRequestDTO: Encodable, Sendable {
    let contentSavedEnabled: Bool
    let dateScheduleEnabled: Bool
    let marketingEnabled: Bool
    /// 마케팅을 켤 때 동의한 약관 버전. nil 이면 키가 실리지 않는다
    let marketingConsentVersion: String?
}
