import SwiftUI
import ThirdParty

public struct MainTabView: View {
    @Bindable public var store: StoreOf<MainTabFeature>

    public init(store: StoreOf<MainTabFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            NavigationStack {
                HomeView(store: store.scope(state: \.home, action: \.home))
            }
            .tabItem { Label("홈", systemImage: "house.fill") }
            .tag(MainTabFeature.Tab.home)

            NavigationStack {
                ExploreView(store: store.scope(state: \.explore, action: \.explore))
            }
            .tabItem { Label("탐색", systemImage: "magnifyingglass") }
            .tag(MainTabFeature.Tab.explore)

            NavigationStack {
                MapView(store: store.scope(state: \.map, action: \.map))
            }
            .tabItem { Label("지도", systemImage: "map.fill") }
            .tag(MainTabFeature.Tab.map)

            NavigationStack {
                MyPageView(store: store.scope(state: \.myPage, action: \.myPage))
                    .navigationTitle("마이페이지")
            }
            .tabItem { Label("마이페이지", systemImage: "person.crop.circle") }
            .tag(MainTabFeature.Tab.myPage)
        }
    }
}
