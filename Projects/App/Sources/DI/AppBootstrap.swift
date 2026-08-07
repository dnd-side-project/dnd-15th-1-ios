import CoreSocialAuth
import Foundation
import SharedLogger
import ThirdParty

enum AppBootstrap {
    @MainActor
    static func run() {
        let infra = InfraContainer.live()
        let configuration = infra.configuration

        KakaoAuthBootstrap.initializeIfNeeded(appKey: configuration.kakaoNativeAppKey)
        GoogleAuthBootstrap.configureIfNeeded(clientID: configuration.googleClientID)

        prepareDependencies {
            Dependencies.register(&$0, infra: infra)
        }

        Logger.shared.info("App bootstrap completed", category: .app)
    }
}
