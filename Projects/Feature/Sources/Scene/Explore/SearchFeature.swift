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
        var recentSearches: [String] = []
        var selectedTab: Tab = .post
        var contents: [Content] = []
        var places: [Place] = []
        var isSearching = false

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
        case searchResponse([Content], [Place])
    }

    @Dependency(\.exploreClient) var exploreClient
    @Dependency(\.recentSearchClient) var recentSearchClient
    @Dependency(\.continuousClock) var clock

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

        case .queryChangeDebounced:
            return search(state: &state)

        case let .searchResponse(contents, places):
            state.contents = contents
            state.places = places
            state.isSearching = false
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
            state.isSearching = false
            return .none
        }
        state.isSearching = true
        return .run { [exploreClient] send in
            async let contents = exploreClient.searchContents(query)
            async let places = exploreClient.searchPlaces(query)
            await send(.searchResponse(try await contents, try await places))
        }
    }

    private func debounceSearch() -> Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: .milliseconds(300))
            await send(.queryChangeDebounced)
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }
}
