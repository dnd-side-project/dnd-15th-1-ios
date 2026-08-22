//
//  ExploreFeature.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Domain
import ThirdParty

@Reducer
public struct ExploreFeature {
    /// 한 번에 받아올 게시물 수. 2열 그리드 기준 다섯 줄이라 진입 직후 재요청 없음
    static let pageSize = 10

    /// 항상 맨 앞에 두는 기본 필터. 뒤로 서버 인기 태그가 붙는다
    static let popularFilter = "인기"

    public enum Route: Hashable {
        case search
    }

    @ObservableState
    public struct State: Equatable {
        var contents: [Content] = []
        var page: Int = 0
        var hasNext: Bool = true
        var isLoadingContents: Bool = false
        var filters: [String] = [ExploreFeature.popularFilter]
        var selectedFilter: String = ExploreFeature.popularFilter
        var search: SearchFeature.State?
        var path: [Route] = []

        // 인기면 기본 제목, 태그를 고르면 그 태그를 제목으로
        var sectionTitle: String {
            selectedFilter == ExploreFeature.popularFilter ? "지금 인기있는 장소" : selectedFilter
        }

        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case reachedEnd
        case contentsResponse(ContentPage)
        case contentsLoadFailed
        case filterTapped(String)
        case searchButtonTapped
        case searchPathChanged([Route])
        case contentTapped(String)
        case search(SearchFeature.Action)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case sessionExpired
            /// 카드 탭. MainTab 이 지도 탭으로 옮겨 상세를 연다
            case showContentDetail(String)
        }
    }

    @Dependency(\.exploreClient) var exploreClient

    private enum CancelID { case load }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
        .ifLet(\.search, action: \.search) {
            SearchFeature()
        }
        .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            // 최초 진입에만 첫 페이지 로드, 탭 재진입 시엔 유지된 목록 그대로 둠
            guard state.contents.isEmpty else { return .none }
            return loadNext(state: &state)

        case .reachedEnd:
            return loadNext(state: &state)

        case let .contentsResponse(page):
            state.isLoadingContents = false
            state.contents += page.items
            state.hasNext = page.hasNext
            updateFilters(state: &state, page: page)
            state.page += 1
            return .none

        case .contentsLoadFailed:
            // page 는 그대로 둬 다음 스크롤에서 같은 페이지 재시도
            state.isLoadingContents = false
            return .none

        case let .filterTapped(filter):
            // 인기=POPULAR, 그 외 태그=검색. 칩을 바꾸면 그리드를 리셋하고 첫 페이지부터 다시 받는다
            guard filter != state.selectedFilter else { return .none }
            state.selectedFilter = filter
            state.contents = []
            state.page = 0
            state.hasNext = true
            state.isLoadingContents = false
            return loadNext(state: &state)

        case .searchButtonTapped, .searchPathChanged, .contentTapped,
             .search, .delegate:
            return navCore(state: &state, action: action)
        }
    }

    private func navCore(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .searchButtonTapped:
            state.search = SearchFeature.State()
            state.path = [.search]
            return .none

        case let .searchPathChanged(path):
            state.path = path
            if path.isEmpty { state.search = nil }
            return .none

        case let .contentTapped(id):
            // 표시는 지도 탭 위에서. MainTab 까지 올린다
            return .send(.delegate(.showContentDetail(id)))

        case let .search(.delegate(.showContentDetail(id))):
            // 검색 결과 카드도 같은 길을 탄다
            return .send(.delegate(.showContentDetail(id)))

        default:
            return .none
        }
    }

    // 인기 태그는 첫 페이지 응답에 담겨 온다. 하드코딩 대신 서버값으로 칩 구성
    private func updateFilters(state: inout State, page: ContentPage) {
        guard state.page == 0, !page.popularTags.isEmpty else { return }
        state.filters = [Self.popularFilter] + page.popularTags.map { "#\($0)" }
    }

    // 로딩 중이거나 마지막 페이지면 무시. 선택 칩이 인기면 목록, 태그면 검색을 받는다
    private func loadNext(state: inout State) -> Effect<Action> {
        guard !state.isLoadingContents, state.hasNext else { return .none }
        state.isLoadingContents = true
        let page = state.page
        let selected = state.selectedFilter
        return .run { [exploreClient] send in
            do {
                let result: ContentPage
                if selected == Self.popularFilter {
                    result = try await exploreClient.contents(.popular, page, Self.pageSize)
                } else {
                    result = try await exploreClient.searchContents(
                        Self.tagQuery(selected), .popular, page, Self.pageSize
                    )
                }
                await send(.contentsResponse(result))
            } catch {
                await send(.contentsLoadFailed)
            }
        }
        // 칩을 바꾸면 진행 중이던 이전 로드를 취소해 결과가 섞이지 않게 한다
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    // "#성수" → "성수". 검색어에는 해시 기호를 빼고 넘긴다
    private static func tagQuery(_ filter: String) -> String {
        filter.hasPrefix("#") ? String(filter.dropFirst()) : filter
    }
}
