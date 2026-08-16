import CoreSocialAuth
import Feature
import Foundation
import SharedLogger
import ThirdParty
import ThirdPartyUI

enum AppBootstrap {
    @MainActor
    static func run() {
        let infra = InfraContainer.make()

        SocialAuthBootstrap.run(infra.socialAuthConfig)
        ImageCacheBootstrap.run(namespace: infra.appConfig.bundleID)
        SDKInitializer.InitSDK(appKey: infra.appConfig.kakaoNativeAppKey)

        prepareDependencies {
            Dependencies.register(&$0, infra: infra)
        }

        Logger.shared.info("App bootstrap completed", category: .app)
    }
}
