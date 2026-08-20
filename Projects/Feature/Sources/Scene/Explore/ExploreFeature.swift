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
        case search(SearchFeature.Action)
    }

    @Dependency(\.exploreClient) var exploreClient

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
            state.selectedFilter = filter
            return .none

        case .searchButtonTapped:
            state.search = SearchFeature.State()
            state.path = [.search]
            return .none

        case let .searchPathChanged(path):
            state.path = path
            if path.isEmpty { state.search = nil }
            return .none

        case .search:
            return .none
        }
    }

    // 인기 태그는 첫 페이지 응답에 담겨 온다. 하드코딩 대신 서버값으로 칩 구성
    private func updateFilters(state: inout State, page: ContentPage) {
        guard state.page == 0, !page.popularTags.isEmpty else { return }
        state.filters = [Self.popularFilter] + page.popularTags.map { "#\($0)" }
    }

    // 로딩 중이거나 마지막 페이지면 무시
    private func loadNext(state: inout State) -> Effect<Action> {
        guard !state.isLoadingContents, state.hasNext else { return .none }
        state.isLoadingContents = true
        let page = state.page
        return .run { [exploreClient] send in
            do {
                let result = try await exploreClient.contents(.popular, page, Self.pageSize)
                await send(.contentsResponse(result))
            } catch {
                await send(.contentsLoadFailed)
            }
        }
    }
}
