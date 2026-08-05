import CoreStorage
import Foundation

struct InfraContainer: Sendable {
    let configuration: AppConfiguration
    let userDefaults: any UserDefaultsStorage
    let keychain: any KeychainStorage
}

extension InfraContainer {
    @MainActor
    static func live() -> InfraContainer {
        let configuration = AppConfiguration.make()
        return InfraContainer(
            configuration: configuration,
            userDefaults: DefaultUserDefaultsStorage(
                suiteName: configuration.bundleID
            ),
            keychain: DefaultKeychainStorage(
                service: configuration.bundleID
            )
        )
    }
}
