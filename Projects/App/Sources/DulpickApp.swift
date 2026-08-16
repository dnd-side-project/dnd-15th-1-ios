import CoreSocialAuth
import Feature
import SwiftUI
import ThirdParty

@main
struct DulpickApp: App {
    private let store: StoreOf<RootFlowFeature>

    init() {
        store = CompositionRoot.makeRootStore()
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
