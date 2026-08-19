import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct MainTabView: View {
    @Bindable public var store: StoreOf<MainTabFeature>

    public init(store: StoreOf<MainTabFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            NavigationStack(path: homeCouplePath) {
                HomeView(store: homeStore)
            }
            .tabItem { tabLabel("홈", icon: .home) }
            .tag(MainTabFeature.Tab.home)

            NavigationStack(path: exploreSearchPath) {
                ExploreView(store: exploreStore)
            }
            .tabItem { tabLabel("탐색", icon: .explore) }
            .tag(MainTabFeature.Tab.explore)

            MapFlowView(store: store.scope(state: \.map, action: \.map))
                .tabItem { tabLabel("지도", icon: .map) }
                .tag(MainTabFeature.Tab.map)

            NavigationStack {
                MyPageView(store: store.scope(state: \.myPage, action: \.myPage))
                    .navigationTitle("마이페이지")
            }
            .tabItem { tabLabel("마이", icon: .my) }
            .tag(MainTabFeature.Tab.myPage)
        }
        .tint(Color.primaryPink)
    }

    // 커플 연결 스택은 홈 스토어가 소유하고, 홈 탭 NavigationStack 이 그 path 를 그대로 민다
    private var homeStore: StoreOf<HomeFeature> {
        store.scope(state: \.home, action: \.home)
    }

    private var homeCouplePath: Binding<[HomeFeature.CoupleRoute]> {
        let homeStore = homeStore
        return Binding(
            get: { homeStore.couplePath },
            set: { homeStore.send(.couplePathChanged($0)) }
        )
    }

    private var exploreStore: StoreOf<ExploreFeature> {
        store.scope(state: \.explore, action: \.explore)
    }

    private var exploreSearchPath: Binding<[ExploreFeature.Route]> {
        let exploreStore = exploreStore
        return Binding(
            get: { exploreStore.path },
            set: { exploreStore.send(.searchPathChanged($0)) }
        )
    }

    private func tabLabel(_ title: String, icon: Image) -> some View {
        Label {
            Text(title)
        } icon: {
            icon.renderingMode(.template)
        }
    }
}
