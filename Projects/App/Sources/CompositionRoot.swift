import Feature
import SwiftUI
import ThirdParty

enum CompositionRoot {
    @MainActor
    static func makeRootStore(infra: InfraContainer) -> StoreOf<RootFlowFeature> {
        AppBootstrap.run(infra)
        return Store(initialState: RootFlowFeature.State()) {
            RootFlowFeature()
        }
    }

    @MainActor
    static func rootView(store: StoreOf<RootFlowFeature>) -> some View {
        RootFlowView(store: store)
    }
}
