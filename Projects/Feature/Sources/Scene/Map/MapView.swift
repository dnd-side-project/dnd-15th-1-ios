import SwiftUI
import ThirdParty

public struct MapView: View {
    @Bindable public var store: StoreOf<MapFeature>

    public init(store: StoreOf<MapFeature>) {
        self.store = store
    }

    public var body: some View {
        Color.clear
            .navigationTitle("지도")
            .task { store.send(.onAppear) }
    }
}
