import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct RootFlowView: View {
    @Bindable public var store: StoreOf<RootFlowFeature>

    public init(store: StoreOf<RootFlowFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.phase {
            case .bootstrapping:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .appIntro:
                if let introStore = store.scope(state: \.appIntro, action: \.appIntro) {
                    AppIntroView(store: introStore)
                }
            case .onboardingFlow:
                if let onboardingStore = store.scope(state: \.onboardingFlow, action: \.onboardingFlow) {
                    OnboardingFlowView(store: onboardingStore)
                }
            case .mainTab:
                if let mainStore = store.scope(state: \.mainTab, action: \.mainTab) {
                    MainTabView(store: mainStore)
                }
            }
        }
        .overlay {
            OverlayView(store: store.scope(state: \.overlay, action: \.overlay))
        }
        // 모달은 시트가 아니라 화면 위에 즉시 얹는 오버레이
        .overlay {
            placeImportModal
        }
        // 덮개는 phase 스위치 바깥에 둔다. 아래가 mainTab 으로 바뀐 뒤 그 위에서 내려가야 한다
        .fullScreenCover(isPresented: dateTypeBinding) {
            dateTypeCover
        }
        .task {
            store.send(.onAppear)
        }
    }

    @ViewBuilder
    private var placeImportModal: some View {
        if let placeImportStore = store.scope(state: \.placeImport, action: \.placeImport.presented) {
            ZStack {
                Color.dimBackground
                    .ignoresSafeArea()

                PlaceImportView(store: placeImportStore)
                    .padding(.horizontal, 20)
            }
        }
    }

    @ViewBuilder
    private var dateTypeCover: some View {
        if let dateTypeStore = store.scope(state: \.onboardingFlow?.dateType, action: \.onboardingFlow.dateType) {
            DateTypeView(store: dateTypeStore)
        }
    }

    // 온보딩이 끝나 phase 가 바뀔 때만 내려간다. 스와이프로 닫히지 않는다
    private var dateTypeBinding: Binding<Bool> {
        Binding(
            get: { store.onboardingFlow?.dateType != nil },
            set: { _ in }
        )
    }
}
