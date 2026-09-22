import Domain
import ThirdParty

@Reducer
public struct NoticeListFeature {
    @ObservableState
    public struct State: Equatable {
        public var notices: [Notice]
        /// 다음에 받아올 페이지 번호
        public var page: Int
        public var hasNext: Bool
        public var hasLoaded: Bool
        public var isLoadingMore: Bool

        public init(
            notices: [Notice] = [],
            page: Int = 0,
            hasNext: Bool = true,
            hasLoaded: Bool = false,
            isLoadingMore: Bool = false
        ) {
            self.notices = notices
            self.page = page
            self.hasNext = hasNext
            self.hasLoaded = hasLoaded
            self.isLoadingMore = isLoadingMore
        }
    }

    public enum Action: Equatable {
        case onAppear
        case noticesLoaded(NoticePage?)
        case reachedEnd
        case moreNoticesLoaded(NoticePage?)
        case backButtonTapped
        case noticeTapped(Notice)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case back
            /// 목록의 줄 탭. 상세 조회가 없어 값을 통째로 올린다
            case noticeSelected(Notice)
        }
    }

    @Dependency(\.noticeClient) var noticeClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            // 상세에서 돌아올 때도 불리므로, 받아 둔 페이지를 덮지 않게 한 번만 받는다
            guard !state.hasLoaded else { return .none }
            return loadPage(0, action: Action.noticesLoaded)

        case let .noticesLoaded(page):
            state.hasLoaded = true
            state.notices = page?.items ?? []
            state.hasNext = page?.hasNext ?? false
            state.page = 1
            return .none

        case .reachedEnd:
            guard state.hasLoaded, state.hasNext, !state.isLoadingMore else { return .none }
            state.isLoadingMore = true
            return loadPage(state.page, action: Action.moreNoticesLoaded)

        case let .moreNoticesLoaded(page):
            state.isLoadingMore = false
            guard let page else { return .none }
            state.notices += page.items
            state.hasNext = page.hasNext
            state.page += 1
            return .none

        case .backButtonTapped:
            return .send(.delegate(.back))

        case let .noticeTapped(notice):
            return .send(.delegate(.noticeSelected(notice)))

        case .delegate:
            return .none
        }
    }

    // 지정한 페이지를 받아 지정한 액션으로 돌려준다. 페이지 크기는 조립 코드가 고정한다
    private func loadPage(
        _ page: Int,
        action: @escaping @Sendable (NoticePage?) -> Action
    ) -> Effect<Action> {
        .run { [noticeClient] send in
            let result = try? await noticeClient.notices(page)
            await send(action(result))
        }
    }
}
