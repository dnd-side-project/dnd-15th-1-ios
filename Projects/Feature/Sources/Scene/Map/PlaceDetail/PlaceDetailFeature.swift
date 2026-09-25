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
            case server(placeID: String)
            case kakao(kakaoPlaceID: String, query: String)
        }

        // id 를 저장 프로퍼티로 둔다. place 를 갈아 끼워도 화면 식별자가 흔들리면 안 된다
        public let id: String

        public var place: Place
        public let alias: String?
        public let source: Source?

        /// 저장 목록에서 오면 켜 둔다. 검색 결과는 꺼 두고 지도가 북마크 집합으로 맞춘다
        public var isBookmarked: Bool

        /// 시안의 `저장한 사람 N`. 모르면 nil 이고 화면이 그 줄을 숨긴다
        public var bookmarkCount: Int?
        /// 조회 응답이 북마크 상태를 덮지 않게 하는 표시
        public var didToggleBookmark = false

        /// 저장 응답이 준 장소 번호. 검색 장소는 장소 번호가 없을 수 있어 삭제엔 이걸 먼저 쓴다
        public var savedServerID: String?

        /// 카카오맵 앱이 없을 때 열 웹 주소. 상세 조회가 끝나면 채워진다
        public var kakaoPlaceURL: URL?

        /// 서버가 아는 공용 장소 번호. 이것이 없으면 게시물을 못 부른다
        public var serverPlaceID: String?

        public var contents: [Content] = []
        public var contentsPage = 0
        public var hasNextContents = true
        public var contentsLoadState: LoadState = .loaded

        public var isAddressExpanded = false

        /// 상세 조회를 이미 시작했는지. 흐름과 화면이 각자 `onAppear` 를 보내 두 번 오는 걸 여기서 막는다
        var didStartLoad = false

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
            source = savedPlace.place.placeID.map { .server(placeID: $0) }
            serverPlaceID = savedPlace.place.placeID
        }

        /// 게시글 상세의 장소. 게시글 응답의 장소 번호가 늘 있어 그 번호로 조회한다
        public init(contentPlace place: Place) {
            id = place.id
            self.place = place
            alias = nil
            isBookmarked = false
            bookmarkCount = place.bookmarkCount
            source = place.placeID.map { .server(placeID: $0) }
            serverPlaceID = place.placeID
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
        case bookmarkSaved(SavedPlace)
        case bookmarkRemoved(serverID: String)
        case bookmarkFailed(wasBookmarked: Bool)
        case addressToggled
        case contentTapped(String)
        case moreTapped
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 장소 id 와 바뀐 뒤 표시 상태. 지도 아이콘 집합을 맞춘다
            case bookmarkToggled(String, Bool)
            /// 저장 응답. 검색 행 id 와 장소 번호가 다를 수 있어 지도 맵·목록에 넣는다
            case bookmarkSaved(String, SavedPlace)
            /// 삭제 성공의 장소 번호. 낙관적 토글과 달리 목록 한 줄을 뺀다
            case bookmarkRemoved(String)
            case contentSelected(String)
            case closed
        }
    }

    @Dependency(\.placeClient) var placeClient
    @Dependency(\.contentClient) var contentClient
    @Dependency(\.analyticsClient) var analyticsClient
    @Dependency(\.authClient) var authClient

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
        case .bookmarkTapped, .bookmarkSaved, .bookmarkRemoved, .bookmarkFailed:
            return updateBookmark(state: &state, action: action)
        case .addressToggled, .contentTapped, .closeTapped, .delegate:
            return updateSheet(state: &state, action: action)
        }
    }

    private func loadDetail(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return startLoad(state: &state)

        case let .detailLoaded(detail):
            // 화면 식별자는 state.id 에 따로 있어 장소를 통째로 갈아 끼워도 흔들리지 않는다
            state.place = detail.place
            state.bookmarkCount = detail.place.bookmarkCount
            state.kakaoPlaceURL = detail.kakaoPlaceURL
            // 조회 중에 북마크를 눌렀으면 응답의 isSaved 는 이미 낡은 값이다
            if !state.didToggleBookmark {
                state.isBookmarked = detail.isSaved
            }
            state.serverPlaceID = state.serverPlaceID ?? detail.place.placeID
            if detail.isSaved, let placeID = detail.place.placeID {
                state.savedServerID = placeID
            }
            let contentsEffect = loadContents(state: &state)
            guard detail.isSaved else { return contentsEffect }
            return .merge(
                .run { [analyticsClient] _ in
                    await analyticsClient.track(.savedPlaceDetailViewed)
                },
                contentsEffect
            )

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
        return .run { [contentClient] send in
            do {
                let result = try await contentClient.placeContents(placeID, page, Self.contentPageSize)
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

        case let .bookmarkSaved(saved):
            state.savedServerID = saved.place.id
            return .merge(
                .run { [analyticsClient, authClient] _ in
                    let userID = (try? await authClient.currentSession())?.userID
                    await analyticsClient.track(.placeSaveCompleted(saveSource: .inApp, userID: userID))
                },
                .send(.delegate(.bookmarkSaved(state.id, saved)))
            )

        case let .bookmarkRemoved(serverID):
            return .send(.delegate(.bookmarkRemoved(serverID)))

        case let .bookmarkFailed(wasBookmarked):
            // 서버 실패 → 표시를 되돌리고 지도에도 원래 값을 알린다
            state.isBookmarked = wasBookmarked
            // 저장 수를 모르면 만들지 않는다
            let delta = wasBookmarked ? 1 : -1
            state.bookmarkCount = state.bookmarkCount.map { max(0, $0 + delta) }
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
}

private extension PlaceDetailFeature {
    enum CancelID {
        case bookmark
        case detail
        case contents
    }

    /// 흐름과 화면이 각자 `onAppear` 를 보낸다. 두 번째는 버린다.
    /// 조회 중에 온 것도, 다 받은 뒤에 온 것도 버린다. 받은 뒤에 통과시키면 누르지 않은 다음 장을 부른다.
    /// 등장으로 다시 부를 일은 없다. 조회가 실패해도 게시물은 `detailLoadFailed` 가 부르고, 게시물 실패는 다시 시도 버튼이 맡는다
    /// 게시물 요청도 끊는다. 흐름이 같은 id 로 바꿔 끼우면 이전 상태의 요청이 살아 있다가 새 상태에 붙는다
    func startLoad(state: inout State) -> Effect<Action> {
        guard !state.didStartLoad, let source = state.source else { return .none }
        state.didStartLoad = true
        return .merge(.cancel(id: CancelID.contents), fetchDetail(source: source))
    }

    func fetchDetail(source: State.Source) -> Effect<Action> {
        .run { [placeClient] send in
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
    }

    /// 저장 버튼. 저장 안 된 상태면 저장, 저장된 상태면 삭제.
    /// 표시를 먼저 뒤집고 서버를 부른 뒤, 실패하면 되돌린다
    func toggleBookmark(state: inout State) -> Effect<Action> {
        let wasBookmarked = state.isBookmarked
        // 저장하려는데 카카오 식별자가 없으면 부를 수 없다
        if !wasBookmarked, state.place.kakaoPlaceID == nil { return .none }
        state.isBookmarked.toggle()
        // 서버가 준 수가 0 일 때 끄면 음수가 된다. 저장 수를 모르면 만들지 않는다
        let delta = state.isBookmarked ? 1 : -1
        state.bookmarkCount = state.bookmarkCount.map { max(0, $0 + delta) }
        return .merge(
            .send(.delegate(.bookmarkToggled(state.id, state.isBookmarked))),
            runBookmark(place: state.place, serverID: state.savedServerID, wasBookmarked: wasBookmarked)
        )
    }

    func runBookmark(place: Place, serverID: String?, wasBookmarked: Bool) -> Effect<Action> {
        let request = Effect<Action>.run { [placeClient] send in
            do {
                if wasBookmarked {
                    // 삭제는 장소 번호로 한다. 둘 다 없으면 저장이 끝나기 전에 다시 누른 경우라 부르지 않고 되돌린다
                    guard let placeID = serverID ?? place.placeID else {
                        await send(.bookmarkFailed(wasBookmarked: wasBookmarked))
                        return
                    }
                    try await placeClient.removePlace(placeID)
                    await send(.bookmarkRemoved(serverID: placeID))
                } else if let kakaoID = place.kakaoPlaceID {
                    let saved = try await placeClient.savePlace(kakaoID, place.name, nil, nil)
                    await send(.bookmarkSaved(saved))
                }
            } catch {
                await send(.bookmarkFailed(wasBookmarked: wasBookmarked))
            }
        }
        // 같은 장소를 연달아 누르면 앞 요청은 버린다
        .cancellable(id: CancelID.bookmark, cancelInFlight: true)
        guard !wasBookmarked else { return request }
        return .merge(
            .run { [analyticsClient] _ in
                await analyticsClient.track(.placeSaveStarted(saveSource: .inApp))
            },
            request
        )
    }
}
