import SwiftUI
import ThirdParty

public struct MapFlowView: View {
    @Bindable public var store: StoreOf<MapFlowFeature>

    public init(store: StoreOf<MapFlowFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: pathBinding) {
            MapView(store: mapStore)
                .navigationDestination(for: MapFlowFeature.Route.self) { route in
                    destination(route)
                }
        }
    }

    // 목적지 화면은 각 Cycle 이 자기 PR 에서 채운다. 그때까지 어느 경로가 밀렸는지만 보인다
    @ViewBuilder
    private func destination(_ route: MapFlowFeature.Route) -> some View {
        switch route {
        case .placeDetail:
            Text("장소 상세 화면 준비 중 — Cycle 2 (DND-49)")
        case .postDetail:
            Text("게시글 상세 화면 준비 중 — Cycle 7")
        case .search:
            if let searchStore = store.scope(state: \.placeSearch, action: \.placeSearch) {
                PlaceSearchView(store: searchStore)
            }
        case .course:
            Text("코스 화면 준비 중 — Cycle 4 (DND-51)")
        }
    }

    private var mapStore: StoreOf<MapFeature> {
        store.scope(state: \.map, action: \.map)
    }

    // 지도 목적지 스택은 MapFlowFeature 가 소유하고, NavigationStack 이 그 path 를 그대로 민다
    private var pathBinding: Binding<[MapFlowFeature.Route]> {
        Binding(
            get: { store.path },
            set: { store.send(.pathChanged($0)) }
        )
    }
}
