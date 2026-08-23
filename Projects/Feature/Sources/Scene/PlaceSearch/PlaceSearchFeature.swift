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

    @ObservableState
    public struct State: Equatable {
        public var query: String = ""
        public var recentSearches: [String] = []
        public var results: [Place] = []
        public var loadState: LoadState = .idle
        /// 지금까지 받은 마지막 페이지 번호. 0 부터 센다
        public var page = 0
        public var hasNext = false
        public var isLoadingMore = false

        /// 검색어가 비면 최근 검색어를 보여준다
        public var showsRecent: Bool {
            query.trimmingCharacters(in: .whitespaces).isEmpty
        }

        /// 다 불러온 뒤 결과가 없는 상태
        public var isEmptyResult: Bool {
            !showsRecent && loadState == .loaded && results.isEmpty
        }

        public init(query: String = "") {
            self.query = query
        }
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case backTapped
        case submitted
        case queryChangeDebounced
        case searchResponse(Result<PlacePage, PlaceError>)
        case reachedEnd
        case moreResponse(Result<PlacePage, PlaceError>)
        case rowTapped(String)
        case recentSearchTapped(String)
        case recentSearchDeleted(String)
        case clearRecentTapped
        case recentSearchesUpdated([String])
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case dismissed
            case searchConfirmed(query: String, places: [Place])
            case placeSelected(Place, query: String)
            case sessionExpired
        }
    }

    private enum CancelID {
        case debounce
        case request
        case more
    }

    @Dependency(\.placeClient) var placeClient
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
        case .binding, .queryChangeDebounced, .searchResponse, .reachedEnd, .moreResponse:
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
        case .binding(\.query):
            return debounce(state: &state)

        case .binding:
            return .none

        case .queryChangeDebounced:
            return search(state: &state)

        case let .searchResponse(.success(page)):
            state.results = page.items
            state.hasNext = page.hasNext
            state.page = 0
            state.loadState = .loaded
            return .none

        case let .searchResponse(.failure(error)):
            state.results = []
            state.loadState = .failed
            if error == .unauthorized {
                return .send(.delegate(.sessionExpired))
            }
            return .none

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

    private func raise(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .backTapped:
            return .send(.delegate(.dismissed))

        case .submitted:
            let query = state.query.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty, !state.results.isEmpty else { return .none }
            let places = state.results
            // 부모가 화면을 닫으면 ifLet 이 남은 효과를 취소하므로 저장을 먼저 끝낸다
            return .concatenate(
                remember(query),
                .send(.delegate(.searchConfirmed(query: query, places: places)))
            )

        case let .rowTapped(id):
            guard let place = state.results.first(where: { $0.id == id }) else {
                return .none
            }
            let query = state.query.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else {
                return .send(.delegate(.placeSelected(place, query: query)))
            }
            // 부모가 화면을 닫으면 ifLet 이 남은 효과를 취소하므로 저장을 먼저 끝낸다
            return .concatenate(
                remember(query),
                .send(.delegate(.placeSelected(place, query: query)))
            )

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    /// 검색어가 비면 돌던 검색을 끊고 결과를 지운다. 서버를 부르지 않는다
    private func debounce(state: inout State) -> Effect<Action> {
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

    private func search(state: inout State) -> Effect<Action> {
        let query = state.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return .none }
        state.page = 0
        state.hasNext = false
        state.isLoadingMore = false
        state.loadState = .loading
        return .run { [placeClient] send in
            do {
                let page = try await placeClient.searchPlaces(query, 0)
                await send(.searchResponse(.success(page)))
            } catch let error as PlaceError {
                await send(.searchResponse(.failure(error)))
            } catch {
                await send(.searchResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.request, cancelInFlight: true)
    }

    private func loadMore(state: inout State) -> Effect<Action> {
        let query = state.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty,
              state.hasNext,
              !state.isLoadingMore,
              state.loadState != .loading
        else { return .none }
        let next = state.page + 1
        state.isLoadingMore = true
        return .run { [placeClient] send in
            do {
                let page = try await placeClient.searchPlaces(query, next)
                await send(.moreResponse(.success(page)))
            } catch let error as PlaceError {
                await send(.moreResponse(.failure(error)))
            } catch {
                await send(.moreResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.more, cancelInFlight: true)
    }

    private func remember(_ query: String) -> Effect<Action> {
        .run { [recentSearchClient] send in
            await send(.recentSearchesUpdated(recentSearchClient.add(query)))
        }
    }
}
