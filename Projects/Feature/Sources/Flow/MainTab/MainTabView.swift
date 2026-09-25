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
            HomeFlowView(store: store.scope(state: \.home, action: \.home))
                .tabItem { tabLabel("홈", icon: .home) }
                .tag(MainTabFeature.Tab.home)

            ExploreFlowView(store: store.scope(state: \.explore, action: \.explore))
                .tabItem { tabLabel("탐색", icon: .explore) }
                .tag(MainTabFeature.Tab.explore)

            MapFlowView(store: store.scope(state: \.map, action: \.map))
                .tabItem { tabLabel("지도", icon: .map) }
                .tag(MainTabFeature.Tab.map)

            MyPageFlowView(store: store.scope(state: \.myPage, action: \.myPage))
                .tabItem { tabLabel("마이", icon: .my) }
                .tag(MainTabFeature.Tab.myPage)
        }
        .tint(Color.primaryPink)
        // 회원탈퇴 모달은 탭뷰 위에 올려 탭바까지 덮고 탭 선택을 막는다
        .modal(isPresented: withdrawModalBinding) {
            ModalContent(
                title: "정말 탈퇴하시나요?",
                content: "지금까지 저장된 데이터가 모두 날아가요",
                image: .modalWarning,
                primaryTitle: "탈퇴하기",
                primaryAction: { myPageFlowStore.send(.withdrawConfirmed) },
                secondaryTitle: "취소",
                secondaryAction: { myPageFlowStore.send(.dismissWithdrawModal) }
            )
        }
    }

    private var myPageFlowStore: StoreOf<MyPageFlowFeature> {
        store.scope(state: \.myPage, action: \.myPage)
    }

    private var withdrawModalBinding: Binding<Bool> {
        let myPageFlowStore = myPageFlowStore
        return Binding(
            get: { myPageFlowStore.isWithdrawModalPresented },
            set: { isPresented in
                if !isPresented {
                    myPageFlowStore.send(.dismissWithdrawModal)
                }
            }
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
