import Domain
import Foundation

enum NotificationDTOMapper {
    static let platform = "IOS"
    static let provider = "FCM"

    static func toRequest(token: String, appVersion: String?) -> NotificationDeviceRequestDTO {
        NotificationDeviceRequestDTO(
            platform: platform,
            provider: provider,
            providerRegistrationId: token,
            appVersion: appVersion
        )
    }

    static func toDomain(_ dto: NotificationSettingsResponseDTO) -> NotificationSettings {
        NotificationSettings(
            contentSavedEnabled: dto.contentSavedEnabled,
            dateScheduleEnabled: dto.dateScheduleEnabled,
            marketingEnabled: dto.marketingEnabled,
            marketingConsentVersion: dto.marketingConsentVersion,
            availableMarketingConsentVersion: dto.availableMarketingConsentVersion
        )
    }

    static func toRequest(_ settings: NotificationSettings) -> NotificationSettingsRequestDTO {
        NotificationSettingsRequestDTO(
            contentSavedEnabled: settings.contentSavedEnabled,
            dateScheduleEnabled: settings.dateScheduleEnabled,
            marketingEnabled: settings.marketingEnabled,
            marketingConsentVersion: settings.marketingConsentVersion
        )
    }
}
