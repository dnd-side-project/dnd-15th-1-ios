import Foundation
import ThirdParty

enum AppBootstrap {
    @MainActor
    static func run() {
        let infra = InfraContainer.live()

        prepareDependencies {
            Dependencies.register(&$0, infra: infra)
        }
    }
}
