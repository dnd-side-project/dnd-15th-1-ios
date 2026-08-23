//
//  PlaceDetailFeature.swift
//  Dulpick
//

import Domain
import Foundation
import ThirdParty

@Reducer
public struct PlaceDetailFeature {
    public enum LoadState: Equatable {
        case loading
        case loaded
        case failed
    }

    /// 한 번에 받는 게시물 수. 「더보기」가 다음 장을 부른다
    static let contentPageSize = 4

    @ObservableState
    public struct State: Equatable, Identifiable {
        /// 상세를 어느 API 로 조회할지. 저장 목록·게시글 장소는 서버 ID,
        /// 검색 결과는 카카오 ID 와 검색어를 쓴다
        public enum Source: Equatable, Sendable {
            case server(placeID: Int)
            case kakao(kakaoPlaceID: String, query: String)
        }

        // id 를 저장 프로퍼티로 둔다. place 를 갈아 끼워도 화면 식별자가 흔들리면 안 된다
        public let id: String

        public var place: Place
        public let alias: String?
        public let source: Source?

        /// 저장 목록에서 오면 켜 둔다. 검색 결과는 꺼 두고 지도가 북마크 집합으로 맞춘다
        public var isBookmarked: Bool

        /// 시안의 `저장한 사람 N`. 상세 조회의 savedMemberCount 로 채운다
        public var bookmarkCount: Int
        /// 조회 응답이 북마크 상태를 덮지 않게 하는 표시
        public var didToggleBookmark = false

        /// 저장 응답이 준 서버 placeId. 검색 장소는 place.id 가 kakaoId 라 삭제 경로엔 이걸 쓴다
        public var savedServerID: String?

        /// 카카오맵 앱이 없을 때 열 웹 주소. 상세 조회가 끝나면 채워진다
        public var kakaoPlaceURL: URL?

        /// 서버가 아는 공용 장소 ID. 이것이 없으면 게시물을 못 부른다
        public var serverPlaceID: Int?

        public var contents: [Content] = []
        public var contentsPage = 0
        public var hasNextContents = true
        public var contentsLoadState: LoadState = .loaded

        public var isAddressExpanded = false

        public var title: String { alias ?? place.name }

        public var kakaoMapAppURL: URL? {
            guard let kakaoPlaceID = place.kakaoPlaceID else { return nil }
            return URL(string: "kakaomap://place?id=\(kakaoPlaceID)")
        }

        /// 앱이 없을 때 여는 웹 주소. 서버가 준 값이 먼저다
        public var kakaoMapWebURL: URL? {
            if let kakaoPlaceURL { return kakaoPlaceURL }
            guard let kakaoPlaceID = place.kakaoPlaceID else { return nil }
            return URL(string: "https://place.map.kakao.com/\(kakaoPlaceID)")
        }

        /// 앱이든 웹이든 열 곳이 있는지. 없으면 지도 버튼이 안 눌린다
        public var canOpenKakaoMap: Bool { kakaoMapAppURL != nil || kakaoMapWebURL != nil }

        public init(savedPlace: SavedPlace) {
            id = savedPlace.place.id
            place = savedPlace.place
            alias = savedPlace.alias
            isBookmarked = true
            bookmarkCount = savedPlace.place.bookmarkCount
            source = Int(savedPlace.place.id).map { .server(placeID: $0) }
            serverPlaceID = Int(savedPlace.place.id)
        }

        /// 게시글 상세의 장소. 게시글 응답의 placeId 가 항상 있어 서버 ID 로 조회한다
        public init(contentPlace place: Place) {
            id = place.id
            self.place = place
            alias = nil
            isBookmarked = false
            bookmarkCount = place.bookmarkCount
            source = Int(place.id).map { .server(placeID: $0) }
            serverPlaceID = Int(place.id)
        }

        /// 검색 결과에서 고른 장소. 카카오 상세는 검색어가 필수다
        public init(place: Place, query: String) {
            id = place.id
            self.place = place
            alias = nil
            isBookmarked = false
            bookmarkCount = place.bookmarkCount
            source = place.kakaoPlaceID.map { .kakao(kakaoPlaceID: $0, query: query) }
        }
    }

    public enum Action: Equatable {
        case onAppear
        case detailLoaded(PlaceDetail)
        case detailLoadFailed
        case contentsResponse(ContentPage)
        case contentsLoadFailed
        case retryContentsTapped
        case bookmarkTapped
        case bookmarkSaved(serverID: String)
        case bookmarkFailed(wasBookmarked: Bool)
        case addressToggled
        case contentTapped(String)
        case moreTapped
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 장소 id 와 바뀐 뒤 상태. 서버 계약이 없어 받는 쪽도 지금은 삼킨다
            case bookmarkToggled(String, Bool)
            case contentSelected(String)
            case closed
        }
    }

    @Dependency(\.placeClient) var placeClient
    @Dependency(\.exploreClient) var exploreClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear, .detailLoaded, .detailLoadFailed:
            return loadDetail(state: &state, action: action)
        case .contentsResponse, .contentsLoadFailed, .retryContentsTapped, .moreTapped:
            return handleContents(state: &state, action: action)
        case .bookmarkTapped, .bookmarkSaved, .bookmarkFailed:
            return updateBookmark(state: &state, action: action)
        case .addressToggled, .contentTapped, .closeTapped, .delegate:
            return updateSheet(state: &state, action: action)
        }
    }

    private func loadDetail(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            guard let source = state.source else { return .none }
            return .run { [placeClient] send in
                do {
                    let detail: PlaceDetail
                    switch source {
                    case let .server(placeID):
                        detail = try await placeClient.placeDetail(placeID)
                    case let .kakao(kakaoPlaceID, query):
                        detail = try await placeClient.kakaoPlaceDetail(kakaoPlaceID, query)
                    }
                    await send(.detailLoaded(detail))
                } catch {
                    // 넘겨받은 값을 그대로 둔다. 사용자에게 알리지 않는다.
                    // 다만 게시물은 아는 서버 ID 로 부를 수 있어 신호를 보낸다
                    await send(.detailLoadFailed)
                }
            }
            .cancellable(id: CancelID.detail, cancelInFlight: true)

        case let .detailLoaded(detail):
            // id 는 안 바꾼다. 화면 식별자가 흔들리면 시트가 다시 그려진다
            state.place = Place(
                id: state.id,
                kakaoPlaceID: detail.place.kakaoPlaceID,
                name: detail.place.name,
                category: detail.place.category,
                address: detail.place.address,
                roadAddress: detail.place.roadAddress,
                coordinate: detail.place.coordinate,
                bookmarkCount: detail.savedMemberCount,
                thumbnailURLs: detail.place.thumbnailURLs
            )
            state.bookmarkCount = detail.savedMemberCount
            state.kakaoPlaceURL = detail.kakaoPlaceURL
            // 조회 중에 북마크를 눌렀으면 응답의 savedByMe 는 이미 낡은 값이다
            if !state.didToggleBookmark {
                state.isBookmarked = detail.savedByMe
            }
            // 매퍼가 placeId 없을 때 카카오 ID 를 place.id 에 넣는다. 둘이 같으면 서버가 모르는 장소다
            let mappedServerID = detail.place.id == detail.place.kakaoPlaceID
                ? nil
                : Int(detail.place.id)
            state.serverPlaceID = state.serverPlaceID ?? mappedServerID
            return loadContents(state: &state)

        case .detailLoadFailed:
            return loadContents(state: &state)

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    private func handleContents(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .contentsResponse(page):
            state.contents += page.items
            state.hasNextContents = page.hasNext
            state.contentsPage += 1
            state.contentsLoadState = .loaded
            return .none

        case .contentsLoadFailed:
            state.contentsLoadState = .failed
            return .none

        case .retryContentsTapped, .moreTapped:
            return loadContents(state: &state)

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    /// 게시물 한 장을 받는다. 서버 ID 가 없으면 섹션이 안 보이므로 부르지 않는다
    private func loadContents(state: inout State) -> Effect<Action> {
        guard let placeID = state.serverPlaceID else {
            state.contentsLoadState = .loaded
            return .none
        }
        guard state.hasNextContents, state.contentsLoadState != .loading else { return .none }
        state.contentsLoadState = .loading
        let page = state.contentsPage
        return .run { [exploreClient] send in
            do {
                let result = try await exploreClient.placeContents(placeID, page, Self.contentPageSize)
                await send(.contentsResponse(result))
            } catch {
                await send(.contentsLoadFailed)
            }
        }
        .cancellable(id: CancelID.contents, cancelInFlight: true)
    }

    private func updateBookmark(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .bookmarkTapped:
            state.didToggleBookmark = true
            return toggleBookmark(state: &state)

        case let .bookmarkSaved(serverID):
            state.savedServerID = serverID
            return .none

        case let .bookmarkFailed(wasBookmarked):
            // 서버 실패 → 표시를 되돌리고 지도에도 원래 값을 알린다
            state.isBookmarked = wasBookmarked
            state.bookmarkCount = max(0, state.bookmarkCount + (wasBookmarked ? 1 : -1))
            return .send(.delegate(.bookmarkToggled(state.id, wasBookmarked)))

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    private func updateSheet(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .addressToggled:
            state.isAddressExpanded.toggle()
            return .none

        case let .contentTapped(id):
            return .send(.delegate(.contentSelected(id)))

        case .closeTapped:
            return .send(.delegate(.closed))

        case .delegate:
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
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
            runBookmark(place: state.place, serverID: state.savedServerID, wasBookmarked: wasBookmarked)
        )
    }

    private func runBookmark(place: Place, serverID: String?, wasBookmarked: Bool) -> Effect<Action> {
        .run { [placeClient] send in
            do {
                if wasBookmarked {
                    // 삭제엔 서버 placeId 를 쓴다. 검색 장소는 place.id 가 kakaoId 일 수 있다
                    try await placeClient.removePlace(serverID ?? place.id)
                } else if let kakaoID = place.kakaoPlaceID {
                    let saved = try await placeClient.savePlace(kakaoID, place.name, nil, nil)
                    await send(.bookmarkSaved(serverID: saved.place.id))
                }
            } catch {
                await send(.bookmarkFailed(wasBookmarked: wasBookmarked))
            }
        }
        // 같은 장소를 연달아 누르면 앞 요청은 버린다
        .cancellable(id: CancelID.bookmark, cancelInFlight: true)
    }
}

private extension PlaceDetailFeature {
    enum CancelID {
        case bookmark
        case detail
        case contents
    }
}
