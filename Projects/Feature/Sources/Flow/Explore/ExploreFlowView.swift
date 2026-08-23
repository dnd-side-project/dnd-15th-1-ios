import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct ExploreFlowView: View {
    @Bindable public var store: StoreOf<ExploreFlowFeature>

    public init(store: StoreOf<ExploreFlowFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: pathBinding) {
            ExploreView(store: store.scope(state: \.explore, action: \.explore))
                .navigationDestination(for: ExploreFlowFeature.Route.self) { route in
                    destination(route)
                }
        }
    }

    @ViewBuilder
    private func destination(_ route: ExploreFlowFeature.Route) -> some View {
        switch route {
        case .search:
            if let searchStore = store.scope(state: \.search, action: \.search) {
                SearchView(store: searchStore)
            }
        }
    }

    // 탐색 목적지 스택은 ExploreFlowFeature 가 소유하고, NavigationStack 이 그 path 를 그대로 민다
    private var pathBinding: Binding<[ExploreFlowFeature.Route]> {
        Binding(
            get: { store.path },
            set: { store.send(.pathChanged($0)) }
        )
    }
}
