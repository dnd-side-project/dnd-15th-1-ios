//
//  SearchFeature.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Domain
import Foundation
import ThirdParty

@Reducer
public struct SearchFeature {
    /// 게시글 검색 한 페이지 크기. 탐색 무한스크롤과 동일하게 맞춘다
    static let pageSize = 10

    public enum Tab: String, Equatable, Sendable, CaseIterable {
        case post
        case place

        var title: String {
            switch self {
            case .post: "게시글"
            case .place: "장소"
            }
        }
    }

    @ObservableState
    public struct State: Equatable {
        var query: String = ""
        var recentSearches: [String] = []
        var selectedTab: Tab = .post
        var contents: [Content] = []
        var places: [Place] = []
        var contentsPage: Int = 0
        var contentsHasNext: Bool = true
        var isSearching = false
        var isLoadingMore = false

        // 선택된 탭 기준으로 결과 유무 판정
        var hasResult: Bool {
            switch selectedTab {
            case .post: !contents.isEmpty
            case .place: !places.isEmpty
            }
        }

        public init() {}
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case searchSubmitted
        case recentSearchTapped(String)
        case recentSearchDeleted(String)
        case clearRecentTapped
        case recentSearchesUpdated([String])
        case tabSelected(Tab)
        case queryChangeDebounced
        case searchResponse(ContentPage, [Place])
        case reachedEnd
        case moreContentsLoaded(ContentPage)
        case searchFailed
    }

    @Dependency(\.exploreClient) var exploreClient
    @Dependency(\.recentSearchClient) var recentSearchClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case search, loadMore }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding(\.query):
            return debounceSearch()

        case .binding:
            return .none

        case .queryChangeDebounced:
            return search(state: &state)

        case let .searchResponse(page, places):
            state.contents = page.items
            state.contentsHasNext = page.hasNext
            state.contentsPage = 1
            state.places = places
            state.isSearching = false
            return .none

        case .reachedEnd:
            return loadMoreContents(state: &state)

        case let .moreContentsLoaded(page):
            state.contents += page.items
            state.contentsHasNext = page.hasNext
            state.contentsPage += 1
            state.isLoadingMore = false
            return .none

        case .searchFailed:
            // 이전 결과는 두고 로딩만 해제
            state.isSearching = false
            state.isLoadingMore = false
            return .none

        case .onAppear, .searchSubmitted, .recentSearchTapped, .recentSearchDeleted,
             .clearRecentTapped, .recentSearchesUpdated, .tabSelected:
            return recentCore(state: &state, action: action)
        }
    }

    // 최근 검색어·탭 전환 처리
    private func recentCore(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .run { [recentSearchClient] send in
                await send(.recentSearchesUpdated(recentSearchClient.load()))
            }

        case .searchSubmitted:
            let query = state.query.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else { return .none }
            return .run { [recentSearchClient] send in
                await send(.recentSearchesUpdated(recentSearchClient.add(query)))
            }

        case let .recentSearchTapped(term):
            state.query = term
            return recentTapped(term)

        case let .recentSearchDeleted(term):
            return .run { [recentSearchClient] send in
                await send(.recentSearchesUpdated(recentSearchClient.remove(term)))
            }

        case .clearRecentTapped:
            return .run { [recentSearchClient] send in
                await recentSearchClient.clear()
                await send(.recentSearchesUpdated([]))
            }

        case let .recentSearchesUpdated(terms):
            state.recentSearches = terms
            return .none

        case let .tabSelected(tab):
            state.selectedTab = tab
            return .none

        default:
            return .none
        }
    }

    private func recentTapped(_ term: String) -> Effect<Action> {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return debounceSearch() }
        return .merge(
            debounceSearch(),
            .run { [recentSearchClient] send in
                await send(.recentSearchesUpdated(recentSearchClient.add(trimmed)))
            }
        )
    }

    private func search(state: inout State) -> Effect<Action> {
        let query = state.query
        guard !query.isEmpty else {
            state.contents = []
            state.places = []
            state.contentsPage = 0
            state.contentsHasNext = true
            state.isSearching = false
            return .none
        }
        state.isSearching = true
        state.contentsPage = 0
        state.contentsHasNext = true
        return .run { [exploreClient] send in
            async let contents = exploreClient.searchContents(query, .popular, 0, Self.pageSize)
            async let places = exploreClient.searchPlaces(query)
            await send(.searchResponse(try await contents, try await places))
        } catch: { error, send in
            // 취소는 실패로 보지 않는다
            if error is CancellationError { return }
            await send(.searchFailed)
        }
    }

    // 게시글 탭 스크롤 끝에서 다음 페이지를 append. 로딩 중·마지막·빈 검색어면 무시
    private func loadMoreContents(state: inout State) -> Effect<Action> {
        let query = state.query
        guard state.selectedTab == .post, !query.isEmpty,
              state.contentsHasNext, !state.isLoadingMore, !state.isSearching else {
            return .none
        }
        state.isLoadingMore = true
        let page = state.contentsPage
        return .run { [exploreClient] send in
            do {
                let result = try await exploreClient.searchContents(query, .popular, page, Self.pageSize)
                await send(.moreContentsLoaded(result))
            } catch {
                if error is CancellationError { return }
                await send(.searchFailed)
            }
        }
        .cancellable(id: CancelID.loadMore, cancelInFlight: true)
    }

    private func debounceSearch() -> Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: .milliseconds(300))
            await send(.queryChangeDebounced)
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }
}
