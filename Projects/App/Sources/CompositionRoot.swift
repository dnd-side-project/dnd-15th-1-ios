import Feature
import SwiftUI
import ThirdParty

enum CompositionRoot {
    @MainActor
    static func makeRootStore() -> StoreOf<RootFlowFeature> {
        AppBootstrap.run()
        return Store(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        }
    }

    @MainActor
    static func rootView(store: StoreOf<RootFlowFeature>) -> some View {
        RootFlowView(store: store)
    }
}
