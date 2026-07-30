import SwiftUI
import ThirdParty

public struct HomeView: View {
    @Bindable public var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        Color.clear
            .navigationTitle("홈")
            .task { store.send(.onAppear) }
    }
}
