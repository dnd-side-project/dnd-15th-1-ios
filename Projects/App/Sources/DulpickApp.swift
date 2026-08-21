import CoreSocialAuth
import Feature
import SwiftUI
import ThirdParty

@main
struct DulpickApp: App {
    private let store: StoreOf<RootFlowFeature>

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let infra = InfraContainer.make()
        store = CompositionRoot.makeRootStore(infra: infra)
        appDelegate.remoteNotificationClient = infra.remoteNotificationClient
    }

    var body: some Scene {
        WindowGroup {
            CompositionRoot.rootView(store: store)
                .onOpenURL { url in
                    if SocialAuthRedirectHandler.handle(url: url) {
                        return
                    }
                    store.send(.deepLinkReceived(url))
                }
        }
    }
}
