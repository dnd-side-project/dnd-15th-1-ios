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
    /// 한 번에 받아올 콘텐츠 수. 2열 그리드 기준 다섯 줄이라 진입 직후 재요청 없음
    static let pageSize = 10

    public enum Route: Hashable {
        case search
    }

    @ObservableState
    public struct State: Equatable {
        var contents: [Content] = []
        var page: Int = 0
        var hasNext: Bool = true
        var isLoadingContents: Bool = false
        var filters: [String] = ["인기", "#성수", "#강남", "#을지로"]
        var selectedFilter: String = "인기"
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
        Reduce { state, action in
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
        .ifLet(\.search, action: \.search) {
            SearchFeature()
        }
        .logged(as: Self.self)
    }

    // 로딩 중이거나 마지막 페이지면 무시
    private func loadNext(state: inout State) -> Effect<Action> {
        guard !state.isLoadingContents, state.hasNext else { return .none }
        state.isLoadingContents = true
        let page = state.page
        return .run { [exploreClient] send in
            do {
                let result = try await exploreClient.contents(page, Self.pageSize)
                await send(.contentsResponse(result))
            } catch {
                await send(.contentsLoadFailed)
            }
        }
    }
}
