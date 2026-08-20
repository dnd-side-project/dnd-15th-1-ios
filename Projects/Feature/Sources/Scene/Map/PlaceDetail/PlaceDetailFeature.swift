//
//  PlaceDetailFeature.swift
//  Dulpick
//

import Domain
import Foundation
import ThirdParty

@Reducer
public struct PlaceDetailFeature {
    /// 더보기 한 번에 붙는 게시물 수
    static let contentPageSize = 4

    @ObservableState
    public struct State: Equatable, Identifiable {
        public var id: String { place.id }

        public let place: Place
        public let alias: String?

        /// 저장 목록에서 오면 켜 둔다. 검색 결과는 꺼 두고 지도가 북마크 집합으로 맞춘다
        public var isBookmarked: Bool

        /// 시안의 `저장한 사람 N`. 서버에 이 값을 바꾸는 길이 없어 화면 안에서만 오르내린다
        public var bookmarkCount: Int

        public var isAddressExpanded = false

        public var visibleContentCount = PlaceDetailFeature.contentPageSize

        public var visibleContents: [Content] {
            Array(RelatedContentMock.contents(for: place.id).prefix(visibleContentCount))
        }

        public var canLoadMore: Bool {
            visibleContentCount < RelatedContentMock.contents(for: place.id).count
        }

        public var title: String { alias ?? place.name }

        public init(savedPlace: SavedPlace) {
            place = savedPlace.place
            alias = savedPlace.alias
            isBookmarked = true
            bookmarkCount = savedPlace.place.bookmarkCount
        }

        public init(place: Place) {
            self.place = place
            alias = nil
            isBookmarked = false
            bookmarkCount = place.bookmarkCount
        }
    }

    public enum Action: Equatable {
        case bookmarkTapped
        case addressToggled
        case mapButtonTapped
        case contentTapped(String)
        case moreTapped
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 장소 id 와 바뀐 뒤 상태. 서버 계약이 없어 받는 쪽도 지금은 삼킨다
            case bookmarkToggled(String, Bool)
            case mapRequested(String)
            case contentSelected(String)
            case closed
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .bookmarkTapped:
            state.isBookmarked.toggle()
            // 서버가 준 수가 0 일 때 끄면 음수가 된다. 화면에 -1 이 뜨는 것을 막는다
            state.bookmarkCount = max(0, state.bookmarkCount + (state.isBookmarked ? 1 : -1))
            return .send(.delegate(.bookmarkToggled(state.id, state.isBookmarked)))

        case .addressToggled:
            state.isAddressExpanded.toggle()
            return .none

        case .moreTapped:
            state.visibleContentCount += Self.contentPageSize
            return .none

        case .mapButtonTapped:
            return .send(.delegate(.mapRequested(state.id)))

        case let .contentTapped(id):
            return .send(.delegate(.contentSelected(id)))

        case .closeTapped:
            return .send(.delegate(.closed))

        case .delegate:
            return .none
        }
    }
}
