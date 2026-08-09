import CoreSocialAuth
import Foundation
import SharedLogger
import ThirdParty

enum AppBootstrap {
    @MainActor
    static func run() {
        let infra = InfraContainer.make()

        SocialAuthBootstrap.run(infra.socialAuthConfig)

        prepareDependencies {
            Dependencies.register(&$0, infra: infra)
        }

        Logger.shared.info("App bootstrap completed", category: .app)
    }
}
