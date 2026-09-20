import Foundation

// MARK: - Notification Settings

struct NotificationSettingsResponseDTO: Decodable, Equatable, Sendable {
    let contentSavedEnabled: Bool
    let dateScheduleEnabled: Bool
    let marketingEnabled: Bool
    let marketingConsentVersion: String?
    let availableMarketingConsentVersion: String?
}
