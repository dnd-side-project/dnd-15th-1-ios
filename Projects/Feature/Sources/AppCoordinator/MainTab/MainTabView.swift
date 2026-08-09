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
            NavigationStack {
                HomeView(store: store.scope(state: \.home, action: \.home))
            }
            .tabItem { tabLabel("홈", icon: .home) }
            .tag(MainTabFeature.Tab.home)

            NavigationStack {
                ExploreView(store: store.scope(state: \.explore, action: \.explore))
            }
            .tabItem { tabLabel("탐색", icon: .explore) }
            .tag(MainTabFeature.Tab.explore)

            NavigationStack {
                MapView(store: store.scope(state: \.map, action: \.map))
            }
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

    private func tabLabel(_ title: String, icon: Image) -> some View {
        Label {
            Text(title)
        } icon: {
            icon.renderingMode(.template)
        }
    }
}
