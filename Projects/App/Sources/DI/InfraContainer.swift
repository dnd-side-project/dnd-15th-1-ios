import CoreNetwork
import CoreSocialAuth
import CoreStorage
import Foundation

struct InfraContainer: Sendable {
    let appConfig: AppConfiguration

    let networkConfig: NetworkConfiguration

    let socialAuthConfig: SocialAuthConfiguration
    let socialAuthClients: SocialAuthClients

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

        let bundleID = appConfig.bundleID
        let userDefaults = DefaultUserDefaultsStorage(suiteName: bundleID)
        let keychain = DefaultKeychainStorage(service: bundleID)

        return InfraContainer(
            appConfig: appConfig,
            networkConfig: networkConfig,
            socialAuthConfig: socialAuthConfig,
            socialAuthClients: socialAuthClients,
            userDefaults: userDefaults,
            keychain: keychain
        )
    }
}
