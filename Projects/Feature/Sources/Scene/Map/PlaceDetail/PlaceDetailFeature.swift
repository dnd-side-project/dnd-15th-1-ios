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
        case bookmarkFailed(wasBookmarked: Bool)
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

    @Dependency(\.placeClient) var placeClient

    private enum CancelID {
        case bookmark
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .bookmarkTapped:
            return toggleBookmark(state: &state)

        case let .bookmarkFailed(wasBookmarked):
            // 서버 실패 → 표시를 되돌리고 지도에도 원래 값을 알린다
            state.isBookmarked = wasBookmarked
            state.bookmarkCount = max(0, state.bookmarkCount + (wasBookmarked ? 1 : -1))
            return .send(.delegate(.bookmarkToggled(state.id, wasBookmarked)))

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

    /// 저장 버튼. 저장 안 된 상태면 저장, 저장된 상태면 삭제.
    /// 표시를 먼저 뒤집고 서버를 부른 뒤, 실패하면 되돌린다
    private func toggleBookmark(state: inout State) -> Effect<Action> {
        let wasBookmarked = state.isBookmarked
        // 저장하려는데 카카오 식별자가 없으면 부를 수 없다
        if !wasBookmarked, state.place.kakaoPlaceID == nil { return .none }
        state.isBookmarked.toggle()
        // 서버가 준 수가 0 일 때 끄면 음수가 된다. 화면에 -1 이 뜨는 것을 막는다
        state.bookmarkCount = max(0, state.bookmarkCount + (state.isBookmarked ? 1 : -1))
        return .merge(
            .send(.delegate(.bookmarkToggled(state.id, state.isBookmarked))),
            runBookmark(place: state.place, wasBookmarked: wasBookmarked)
        )
    }

    private func runBookmark(place: Place, wasBookmarked: Bool) -> Effect<Action> {
        .run { [placeClient] send in
            do {
                if wasBookmarked {
                    try await placeClient.removePlace(place.id)
                } else if let kakaoID = place.kakaoPlaceID {
                    _ = try await placeClient.savePlace(kakaoID, place.name, nil, nil)
                }
            } catch {
                await send(.bookmarkFailed(wasBookmarked: wasBookmarked))
            }
        }
        // 같은 장소를 연달아 누르면 앞 요청은 버린다
        .cancellable(id: CancelID.bookmark, cancelInFlight: true)
    }
}
