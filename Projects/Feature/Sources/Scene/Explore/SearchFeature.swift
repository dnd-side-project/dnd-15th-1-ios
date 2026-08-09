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
        // 임시 최근 검색어, 나중에 UserDefaults 로 대체
        var recentSearches: [String] = ["카페", "블루베리", "스무디"]
        var selectedTab: Tab = .post
        var posts: [Post] = []
        var places: [Place] = []
        var isSearching = false

        var hasResult: Bool {
            !posts.isEmpty || !places.isEmpty
        }

        public init() {}
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case recentSearchTapped(String)
        case recentSearchDeleted(String)
        case clearRecentTapped
        case tabSelected(Tab)
        case queryChangeDebounced
        case searchResponse([Post], [Place])
    }

    @Dependency(\.exploreClient) var exploreClient

    private enum CancelID { case search }

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

        case let .recentSearchTapped(term):
            state.query = term
            return debounceSearch()

        case let .recentSearchDeleted(term):
            state.recentSearches.removeAll { $0 == term }
            return .none

        case .clearRecentTapped:
            state.recentSearches.removeAll()
            return .none

        case let .tabSelected(tab):
            state.selectedTab = tab
            return .none

        case .queryChangeDebounced:
            return search(state: &state)

        case let .searchResponse(posts, places):
            state.posts = posts
            state.places = places
            state.isSearching = false
            return .none
        }
    }

    private func search(state: inout State) -> Effect<Action> {
        let query = state.query
        guard !query.isEmpty else {
            state.posts = []
            state.places = []
            state.isSearching = false
            return .none
        }
        state.isSearching = true
        return .run { [exploreClient] send in
            async let posts = exploreClient.searchPosts(query)
            async let places = exploreClient.searchPlaces(query)
            await send(.searchResponse(try await posts, try await places))
        }
    }

    private func debounceSearch() -> Effect<Action> {
        .send(.queryChangeDebounced)
            .debounce(id: CancelID.search, for: .milliseconds(300), scheduler: DispatchQueue.main)
    }
}
