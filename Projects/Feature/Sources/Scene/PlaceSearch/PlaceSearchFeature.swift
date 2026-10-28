import Domain
import Foundation
import ThirdParty

@Reducer
public struct PlaceSearchFeature {
    public init() {}

    public enum LoadState: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed
    }

    /// 두 검색 API 의 실패를 화면이 가르는 만큼만 나눈다
    public enum SearchFailure: Error, Equatable, Sendable {
        /// 세션 만료. 위로 올려 로그인으로 보낸다
        case unauthorized
        /// 그 밖의 실패. 커플 연결이 끊겨 온 404 도 여기다. 화면은 실패 문구 하나만 보인다
        case other
    }

    @ObservableState
    public struct State: Equatable {
        public var query: String = ""
        public var recentSearches: [String] = []
        public var results: [PlaceSearchResult] = []
        public var loadState: LoadState = .idle
        /// 지금까지 받은 마지막 페이지 번호. 0 부터 센다
        public var page = 0
        public var hasNext = false
        public var isLoadingMore = false
        /// 「저장한 곳만 보기」. 켜면 커플이 저장한 장소만 코스 장소 검색으로 찾는다
        public var isSavedOnly = false
        /// 커플이 연결돼야 토글 줄이 보인다. 커플이 없으면 서버가 404 를 준다
        public var isCoupleConnected = false

        /// 검색어가 비면 최근 검색어를 보여준다. 토글이 켜져 있어도 같다
        public var showsRecent: Bool {
            query.trimmingCharacters(in: .whitespaces).isEmpty
        }

        /// 다 불러온 뒤 결과가 없는 상태
        public var isEmptyResult: Bool {
            !showsRecent && loadState == .loaded && results.isEmpty
        }

        public init(query: String = "", isSavedOnly: Bool = false, isCoupleConnected: Bool = false) {
            self.query = query
            self.isCoupleConnected = isCoupleConnected
            // 토글 줄이 없는 사람이 켜진 토글을 물려받으면 끌 길이 없다
            self.isSavedOnly = isCoupleConnected && isSavedOnly
        }
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case backTapped
        case submitted
        case queryChangeDebounced
        case searchResponse(Result<Page<PlaceSearchResult>, SearchFailure>)
        case reachedEnd
        case moreResponse(Result<Page<PlaceSearchResult>, SearchFailure>)
        case rowTapped(String)
        case recentSearchTapped(String)
        case recentSearchDeleted(String)
        case clearRecentTapped
        case recentSearchesUpdated([String])
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case dismissed
            /// 엔터. 지금 결과와 토글 상태를 지도에 깐다
            case searchConfirmed(query: String, results: [PlaceSearchResult], isSavedOnly: Bool)
            /// 토글을 끈 결과 행. 카카오 번호와 검색어로 상세를 연다
            case placeSelected(PlaceSearchResult, query: String)
            /// 「저장한 곳만 보기」 결과 행. 카카오 번호가 없어 저장 목록처럼 장소 번호로 상세를 연다
            case savedPlaceSelected(SavedPlace)
            case sessionExpired
        }
    }

    private enum CancelID {
        case debounce
        case request
        case more
    }

    @Dependency(\.placeClient) var placeClient
    @Dependency(\.courseClient) var courseClient
    @Dependency(\.mapRecentSearchClient) var recentSearchClient
    @Dependency(\.continuousClock) var clock

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear, .recentSearchTapped, .recentSearchDeleted, .clearRecentTapped, .recentSearchesUpdated:
            return updateRecent(state: &state, action: action)
        case .binding:
            return updateBinding(state: &state, action: action)
        case .queryChangeDebounced, .searchResponse, .reachedEnd, .moreResponse:
            return updateSearch(state: &state, action: action)
        case .backTapped, .submitted, .rowTapped:
            return raise(state: &state, action: action)
        case .delegate:
            return .none
        }
    }

    private func updateRecent(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            let loadRecent = Effect<Action>.run { [recentSearchClient] send in
                await send(.recentSearchesUpdated(recentSearchClient.load()))
            }
            let query = state.query.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else { return loadRecent }
            return .merge(loadRecent, search(state: &state))

        case let .recentSearchTapped(term):
            state.query = term
            return debounce(state: &state)

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

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    private func updateSearch(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .queryChangeDebounced:
            return search(state: &state)

        case let .searchResponse(.success(page)):
            state.results = page.items
            state.hasNext = page.hasNext
            state.page = 0
            state.loadState = .loaded
            return .none

        case let .searchResponse(.failure(failure)):
            state.results = []
            state.loadState = .failed
            guard failure == .unauthorized else { return .none }
            return .send(.delegate(.sessionExpired))

        case .reachedEnd:
            return loadMore(state: &state)

        case let .moreResponse(.success(page)):
            state.results += page.items
            state.hasNext = page.hasNext
            state.page += 1
            state.isLoadingMore = false
            return .none

        case .moreResponse(.failure):
            // 첫 페이지는 화면에 남긴다. hasNext 를 끄면 일시 실패가 영구 정지가 된다
            state.isLoadingMore = false
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }
}

private extension PlaceSearchFeature {
    func updateBinding(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding(\.query):
            return debounce(state: &state)
        case .binding(\.isSavedOnly):
            return searchNow(state: &state)
        default:
            return .none
        }
    }

    func raise(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .backTapped:
            return .send(.delegate(.dismissed))

        case .submitted:
            let query = state.query.trimmingCharacters(in: .whitespaces)
            // 로딩 중엔 상태에 이전 토글의 결과가 남아 있다. 그대로 올리면 토글 상태와 결과가 어긋난다
            guard !query.isEmpty, state.loadState == .loaded, !state.results.isEmpty else { return .none }
            let confirmed = Action.Delegate.searchConfirmed(
                query: query,
                results: state.results,
                isSavedOnly: state.isSavedOnly
            )
            // 부모가 화면을 닫으면 ifLet 이 남은 효과를 취소하므로 저장을 먼저 끝낸다
            return .concatenate(remember(query), .send(.delegate(confirmed)))

        case let .rowTapped(id):
            guard let result = state.results.first(where: { $0.id == id }) else {
                return .none
            }
            let query = state.query.trimmingCharacters(in: .whitespaces)
            let selected = selection(of: result, query: query, isSavedOnly: state.isSavedOnly)
            guard !query.isEmpty else {
                return .send(.delegate(selected))
            }
            // 부모가 화면을 닫으면 ifLet 이 남은 효과를 취소하므로 저장을 먼저 끝낸다
            return .concatenate(remember(query), .send(.delegate(selected)))

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    /// 토글 결과는 카카오 번호가 없어 저장 목록처럼 연다. 토글을 끈 결과는 저장했어도 카카오 상세로 연다
    func selection(of result: PlaceSearchResult, query: String, isSavedOnly: Bool) -> Action.Delegate {
        if isSavedOnly, let saved = result.savedPlace {
            return .savedPlaceSelected(saved)
        }
        return .placeSelected(result, query: query)
    }

    /// 검색어가 비면 돌던 검색을 끊고 결과를 지운다. 서버를 부르지 않는다
    func debounce(state: inout State) -> Effect<Action> {
        let query = state.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            state.results = []
            state.loadState = .idle
            return .merge(
                .cancel(id: CancelID.debounce),
                .cancel(id: CancelID.request),
                .cancel(id: CancelID.more)
            )
        }
        // 새 검색어를 치면 돌던 요청도 끊는다. 안 끊으면 옛 응답이 새 검색어 화면에 얹힌다
        return .merge(
            .cancel(id: CancelID.request),
            .cancel(id: CancelID.more),
            .run { [clock] send in
                try await clock.sleep(for: .milliseconds(300))
                await send(.queryChangeDebounced)
            }
            .cancellable(id: CancelID.debounce, cancelInFlight: true)
        )
    }

    /// 토글을 바꾸면 기다리지 않고 지금 검색어로 다시 찾는다. 기다리던 검색과 돌던 요청은 끊는다
    func searchNow(state: inout State) -> Effect<Action> {
        // 검색어가 비면 최근 검색어를 보이는 중이라 부를 것이 없다
        guard !state.showsRecent else { return .none }
        return .merge(
            .cancel(id: CancelID.debounce),
            .cancel(id: CancelID.more),
            search(state: &state)
        )
    }

    func search(state: inout State) -> Effect<Action> {
        let query = state.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return .none }
        state.page = 0
        state.hasNext = false
        state.isLoadingMore = false
        state.loadState = .loading
        let isSavedOnly = state.isSavedOnly
        return .run { [placeClient, courseClient] send in
            let result = await Self.fetchPage(
                query: query,
                page: 0,
                isSavedOnly: isSavedOnly,
                placeClient: placeClient,
                courseClient: courseClient
            )
            await send(.searchResponse(result))
        }
        .cancellable(id: CancelID.request, cancelInFlight: true)
    }

    func loadMore(state: inout State) -> Effect<Action> {
        let query = state.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty,
              state.hasNext,
              !state.isLoadingMore,
              state.loadState != .loading
        else { return .none }
        let next = state.page + 1
        let isSavedOnly = state.isSavedOnly
        state.isLoadingMore = true
        return .run { [placeClient, courseClient] send in
            let result = await Self.fetchPage(
                query: query,
                page: next,
                isSavedOnly: isSavedOnly,
                placeClient: placeClient,
                courseClient: courseClient
            )
            await send(.moreResponse(result))
        }
        .cancellable(id: CancelID.more, cancelInFlight: true)
    }

    func remember(_ query: String) -> Effect<Action> {
        .run { [recentSearchClient] send in
            await send(.recentSearchesUpdated(recentSearchClient.add(query)))
        }
    }

    /// 토글이 켜져 있으면 커플 저장 장소 검색을, 꺼져 있으면 지도 검색을 부른다. 두 결과를 한 모양으로 돌려준다
    static func fetchPage(
        query: String,
        page: Int,
        isSavedOnly: Bool,
        placeClient: PlaceClient,
        courseClient: CourseClient
    ) async -> Result<Page<PlaceSearchResult>, SearchFailure> {
        do {
            guard isSavedOnly else {
                return .success(try await placeClient.searchPlaces(query, page))
            }
            let saved = try await courseClient.searchCoursePlaces(query, page)
            return .success(
                Page(items: saved.items.map(PlaceSearchResult.init(savedPlace:)), hasNext: saved.hasNext)
            )
        } catch PlaceError.unauthorized, CourseError.unauthorized {
            return .failure(.unauthorized)
        } catch {
            return .failure(.other)
        }
    }
}
