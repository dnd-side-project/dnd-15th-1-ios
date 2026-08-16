import SwiftUI
import ThirdParty

public struct OnboardingFlowView: View {
    @Bindable public var store: StoreOf<OnboardingFlowFeature>

    public init(store: StoreOf<OnboardingFlowFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: pathBinding) {
            AuthView(store: store.scope(state: \.auth, action: \.auth))
                // 로그인은 바 없이 그린다. 바를 두면 내용이 통째로 밀린다
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: OnboardingFlowFeature.Route.self) { route in
                    destination(route)
                }
        }
    }

    // 커플 세 화면은 같은 store 를 받는다. Route 는 그중 무엇을 그릴지만 가른다
    @ViewBuilder
    private func destination(_ route: OnboardingFlowFeature.Route) -> some View {
        switch route {
        case .nickname:
            NicknameView(store: store.scope(state: \.nickname, action: \.nickname))
        case .couple:
            if let coupleStore { CoupleConnectView(store: coupleStore) }
        case .coupleCodeInput:
            if let coupleStore { CoupleCodeInputView(store: coupleStore) }
        case .coupleComplete:
            if let coupleStore { CoupleCompleteView(store: coupleStore) }
        }
    }

    private var coupleStore: StoreOf<CoupleConnectFeature>? {
        store.scope(state: \.couple, action: \.couple)
    }

    private var pathBinding: Binding<[OnboardingFlowFeature.Route]> {
        Binding(
            get: { store.path },
            set: { store.send(.pathChanged($0)) }
        )
    }
}

#if DEBUG
#Preview("로그인") {
    OnboardingFlowView(
        store: Store(initialState: OnboardingFlowFeature.State()) {
            OnboardingFlowFeature()
        }
    )
}

#Preview("닉네임") {
    OnboardingFlowView(
        store: Store(initialState: OnboardingFlowFeature.State.resumingOnboarding) {
            OnboardingFlowFeature()
        }
    )
}

#Preview("커플 연결") {
    OnboardingFlowView(
        store: Store(
            initialState: OnboardingFlowFeature.State(
                nickname: NicknameFeature.State(isTermsSheetPresented: false),
                couple: CoupleConnectFeature.State(myNickname: "둘픽"),
                path: [.nickname, .couple]
            )
        ) {
            OnboardingFlowFeature()
        }
    )
}
#endif
