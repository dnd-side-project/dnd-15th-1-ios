import Domain
import SwiftUI
import ThirdParty

public struct MapView: View {
    @Bindable public var store: StoreOf<MapFeature>

    public init(store: StoreOf<MapFeature>) {
        self.store = store
    }

    public var body: some View {
        DulpickMapView(
            camera: Binding(
                get: { store.camera },
                set: { store.send(.cameraChanged($0)) }
            ),
            markers: store.markers,
            onMarkerTap: { store.send(.markerTapped($0)) }
        )
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { store.send(.onAppear) }
    }
}

#if DEBUG
#Preview {
    KakaoMapPreviewContainer {
        MapView(
            store: Store(initialState: MapFeature.State()) {
                MapFeature()
            } withDependencies: {
                $0.placeClient = .mock
            }
        )
    }
}
#endif
