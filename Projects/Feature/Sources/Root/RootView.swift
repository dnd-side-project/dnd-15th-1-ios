import SwiftUI
import ThirdParty

public struct RootView: View {
    @Bindable public var store: StoreOf<RootFeature>

    public init(store: StoreOf<RootFeature>) {
        self.store = store
    }

    public var body: some View {
        AppCoordinatorView(
            store: store.scope(state: \.appCoordinator, action: \.appCoordinator)
        )
    }
}
