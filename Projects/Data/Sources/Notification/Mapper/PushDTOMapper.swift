import Foundation

enum PushDTOMapper {
    static let platform = "IOS"
    static let provider = "FCM"

    static func toRequest(token: String, appVersion: String?) -> PushDeviceRequestDTO {
        PushDeviceRequestDTO(
            platform: platform,
            provider: provider,
            providerRegistrationId: token,
            appVersion: appVersion
        )
    }
}
