//
//  SearchFeature.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import ThirdParty

@Reducer
public struct SearchFeature {
    @ObservableState
    public struct State: Equatable {
        var query: String = ""
        // 임시 최근 검색어, 나중에 UserDefaults 로 대체
        var recentSearches: [String] = ["카페", "블루베리", "스무디"]

        public init() {}
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case recentSearchTapped(String)
        case recentSearchDeleted(String)
        case clearRecentTapped
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .recentSearchTapped(term):
                state.query = term
                return .none

            case let .recentSearchDeleted(term):
                state.recentSearches.removeAll { $0 == term }
                return .none

            case .clearRecentTapped:
                state.recentSearches.removeAll()
                return .none
            }
        }
    }
}
