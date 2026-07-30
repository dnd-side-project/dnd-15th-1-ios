import SwiftUI
import ThirdParty

public struct ExploreView: View {
    @Bindable public var store: StoreOf<ExploreFeature>

    public init(store: StoreOf<ExploreFeature>) {
        self.store = store
    }

    public var body: some View {
        Color.clear
            .navigationTitle("탐색")
            .task { store.send(.onAppear) }
    }
}
