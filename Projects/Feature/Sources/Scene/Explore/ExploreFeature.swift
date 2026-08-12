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
    @ObservableState
    public struct State: Equatable {
        var posts: [Post] = []
        var filters: [String] = ["인기", "#성수", "#강남", "#을지로"]
        var selectedFilter: String = "인기"
        @Presents var search: SearchFeature.State?

        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case filterTapped(String)
        case searchButtonTapped
        case popularPostsResponse([Post])
        case search(PresentationAction<SearchFeature.Action>)
    }

    @Dependency(\.exploreClient) var exploreClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [exploreClient] send in
                    let posts = try await exploreClient.popularPosts()
                    await send(.popularPostsResponse(posts))
                }

            case let .filterTapped(filter):
                state.selectedFilter = filter
                return .none

            case .searchButtonTapped:
                state.search = SearchFeature.State()
                return .none

            case let .popularPostsResponse(posts):
                state.posts = posts
                return .none

            case .search:
                return .none
            }
        }
        .ifLet(\.$search, action: \.search) {
            SearchFeature()
        }
        .logged(as: Self.self)
    }
}
