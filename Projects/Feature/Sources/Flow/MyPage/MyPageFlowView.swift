import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct MyPageFlowView: View {
    @Bindable public var store: StoreOf<MyPageFlowFeature>

    public init(store: StoreOf<MyPageFlowFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: pathBinding) {
            MyPageView(store: store.scope(state: \.myPage, action: \.myPage))
                .navigationDestination(for: MyPageFlowFeature.Route.self) { route in
                    destination(route)
                }
        }
    }

    // push 목적지. 각 화면은 하단탭을 스스로 숨긴다
    @ViewBuilder
    private func destination(_ route: MyPageFlowFeature.Route) -> some View {
        switch route {
        case .dateType:
            dateTypeDestination
        case .connection:
            connectionDestination
        case .connect, .codeInput, .complete:
            coupleDestination(route)
        }
    }

    // 미연결 시 타는 커플 연결 3화면. 각 뷰가 자체 back·nav 를 가진다
    @ViewBuilder
    private func coupleDestination(_ route: MyPageFlowFeature.Route) -> some View {
        if let coupleStore = store.scope(state: \.couple, action: \.couple) {
            Group {
                switch route {
                case .codeInput:
                    CoupleCodeInputView(store: coupleStore)
                case .complete:
                    CoupleCompleteView(store: coupleStore)
                default:
                    CoupleConnectView(store: coupleStore)
                }
            }
            .toolbar(.hidden, for: .tabBar)
        }
    }

    @ViewBuilder
    private var dateTypeDestination: some View {
        if let dateTypeStore = store.scope(state: \.dateType, action: \.dateType) {
            DateTypeView(store: dateTypeStore)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    backToolbarItem
                    ToolbarItem(placement: .principal) {
                        Text("나의 데이트 유형")
                            .typography(.body1SB)
                            .foregroundStyle(Color.commonWhite)
                    }
                }
                .toolbar(.hidden, for: .tabBar)
        }
    }

    @ViewBuilder
    private var connectionDestination: some View {
        if let connectionStore = store.scope(state: \.connection, action: \.connection) {
            ConnectionManageView(store: connectionStore)
                .navigationTitle("연결 관리")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar { backToolbarItem }
                .toolbar(.hidden, for: .tabBar)
        }
    }

    private var backToolbarItem: some ToolbarContent {
        BackToolbarItem { store.send(.pathChanged([])) }
    }

    // 마이 목적지 스택은 MyPageFlowFeature 가 소유하고, NavigationStack 이 그 path 를 그대로 민다
    private var pathBinding: Binding<[MyPageFlowFeature.Route]> {
        Binding(
            get: { store.path },
            set: { store.send(.pathChanged($0)) }
        )
    }
}
