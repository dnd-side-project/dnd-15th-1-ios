import CoreNotification
import CoreSocialAuth
import Feature
import Foundation
import SharedLogger
import ThirdParty
import ThirdPartyUI

enum AppBootstrap {
    @MainActor
    static func run(_ infra: InfraContainer) {
        SocialAuthBootstrap.run(infra.socialAuthConfig)
        NotificationBootstrap.run(infra.notificationConfig, client: infra.remoteNotificationClient)
        ImageCacheBootstrap.run(namespace: infra.appConfig.bundleID)
        SDKInitializer.InitSDK(appKey: infra.appConfig.kakaoNativeAppKey)

        prepareDependencies {
            Dependencies.register(&$0, infra: infra)
        }

        Logger.shared.info("App bootstrap completed", category: .app)
    }
}
