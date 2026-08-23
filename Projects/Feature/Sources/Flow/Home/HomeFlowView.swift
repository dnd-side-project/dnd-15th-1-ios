import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct HomeFlowView: View {
    @Bindable public var store: StoreOf<HomeFlowFeature>

    public init(store: StoreOf<HomeFlowFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: pathBinding) {
            HomeView(store: store.scope(state: \.home, action: \.home))
                .navigationDestination(for: HomeFlowFeature.Route.self) { route in
                    destination(route)
                }
        }
    }

    @ViewBuilder
    private func destination(_ route: HomeFlowFeature.Route) -> some View {
        switch route {
        case .connect, .codeInput, .complete:
            coupleDestination(route)
        case .pastDateCourses:
            // 검색 화면과 동일하게 뷰를 직접 렌더하고 tabBar 숨김은 그 뷰가 스스로 처리한다
            if let pastStore {
                PastDateCoursesView(store: pastStore)
            }
        case .course:
            // 코스 두 화면도 tabBar 숨김을 스스로 하므로 직접 렌더한다
            if let courseStore {
                CourseDateView(store: courseStore)
            }
        case .coursePlacePick:
            if let courseStore {
                CoursePlacePickView(store: courseStore)
            }
        case .courseResult:
            if let courseResultStore {
                CourseResultView(store: courseResultStore)
            }
        }
    }

    // 커플 세 화면은 같은 스토어를 공유. push 동안 하단탭은 숨긴다
    @ViewBuilder
    private func coupleDestination(_ route: HomeFlowFeature.Route) -> some View {
        if let coupleStore {
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

    private var coupleStore: StoreOf<CoupleConnectFeature>? {
        store.scope(state: \.couple, action: \.couple)
    }

    private var pastStore: StoreOf<PastDateCoursesFeature>? {
        store.scope(state: \.pastDateCourses, action: \.pastDateCourses)
    }

    private var courseStore: StoreOf<CourseFeature>? {
        store.scope(state: \.course, action: \.course)
    }

    private var courseResultStore: StoreOf<CourseResultFeature>? {
        store.scope(state: \.courseResult, action: \.courseResult)
    }

    // 홈 목적지 스택은 HomeFlowFeature 가 소유하고, NavigationStack 이 그 path 를 그대로 민다
    private var pathBinding: Binding<[HomeFlowFeature.Route]> {
        Binding(
            get: { store.path },
            set: { store.send(.pathChanged($0)) }
        )
    }
}
