import CoreNetwork
import CoreNotification
import CoreSocialAuth
import CoreStorage
import Foundation

struct InfraContainer: Sendable {
    let appConfig: AppConfiguration

    let networkConfig: NetworkConfiguration

    let socialAuthConfig: SocialAuthConfiguration
    let socialAuthClients: SocialAuthClients

    let notificationConfig: NotificationConfiguration
    let remoteNotificationClient: RemoteNotificationClient

    let userDefaults: any UserDefaultsStorage
    let keychain: any KeychainStorage
}

extension InfraContainer {
    @MainActor
    static func make() -> InfraContainer {
        let appConfig = AppConfiguration.make()

        let networkConfig = NetworkConfiguration(baseURL: appConfig.baseURL)

        let socialAuthConfig = SocialAuthConfiguration(
            kakaoAppKey: appConfig.kakaoNativeAppKey,
            googleClientID: appConfig.googleClientID
        )
        let socialAuthClients = SocialAuthClientFactory().make()

        let notificationConfig = NotificationConfiguration(
            firebaseOptionsResourceName: appConfig.firebaseOptionsResourceName
        )
        let remoteNotificationClient = RemoteNotificationClientFactory().make()

        let bundleID = appConfig.bundleID
        let userDefaults = DefaultUserDefaultsStorage()
        let keychain = DefaultKeychainStorage(service: bundleID)

        return InfraContainer(
            appConfig: appConfig,
            networkConfig: networkConfig,
            socialAuthConfig: socialAuthConfig,
            socialAuthClients: socialAuthClients,
            notificationConfig: notificationConfig,
            remoteNotificationClient: remoteNotificationClient,
            userDefaults: userDefaults,
            keychain: keychain
        )
    }
}
