import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct MapFeature {
    public enum LoadState: Equatable, Sendable {
        case loading
        case loaded
        case failed
    }

    @ObservableState
    public struct State: Equatable {
        /// 지도가 무엇을 그리고 있는지. 검색 결과가 들어오면 저장 장소를 잠시 덮는다
        public enum Mode: Equatable, Sendable {
            case saved40
            case searchResult(query: String, places: [Place])
        }

        /// 지금 열린 상세의 장소. 흐름이 채우고, 지도는 선택 핀만 이걸로 그린다
        public struct SelectedPlace: Equatable, Sendable {
            public let id: String
            public let coordinate: Coordinate

            public init(id: String, coordinate: Coordinate) {
                self.id = id
                self.coordinate = coordinate
            }
        }

        public var camera: MapCamera = .ansan
        public var mode: Mode = .saved

        /// 저장 여부 표시. 서버 계약이 없어 화면 안에서만 산다
        public var bookmarkedPlaceIDs: Set<String> = []
        public var places: [SavedPlace] = []
        public var loadState: LoadState = .loading

        /// 커플이 연동되어야 저장자 칩이 보인다. 미연동이면 `함께 저장한`(전부) 으로 고정된다
        public var isCoupleConnected = false

        /// `nil` 이면 전체다
        public var selectedCategory: PlaceCategory?
        public var selectedOwnership: PlaceOwnership = .together

        /// `⋮` 팝오버가 열려 있는 행. `nil` 이면 닫혀 있다
        public var menuTargetPlaceID: String?

        public var toast: ToastState?

        /// 지금 열린 상세. `nil` 이면 선택 핀을 안 그린다
        public var selectedPlace: SelectedPlace?

        /// 지도 핀과 시트 목록이 함께 보는 하나의 배열이다. 둘이 어긋날 수 없다
        public var filteredPlaces: [SavedPlace] {
            places
                .filter { selectedOwnership.matches($0.ownership) }
                .filter { selectedCategory == nil || $0.place.category == selectedCategory }
        }

        /// 다 불러온 뒤 보일 게 없는 상태
        public var isEmpty: Bool {
            loadState == .loaded && filteredPlaces.isEmpty
        }

        /// 저장한 장소 자체가 없다. 필터 때문에 빈 것과 문구가 다르다
        public var hasNoSavedPlace: Bool {
            loadState == .loaded && places.isEmpty
        }

        public init() {}
    }

    public enum Action: Equatable {
        case onAppear
        case savedPlacesResponse(Result<[SavedPlace], PlaceError>)
        case coupleResponse(Bool)
        case cameraChanged(MapCamera)
        case categoryTapped(PlaceCategory?)
        case ownershipSelected(PlaceOwnership)
        case rowMenuTapped(String)
        case rowMenuDismissed
        case editTapped(String)
        case deleteTapped(String)
        case markerTapped(String)
        case rowTapped(String)
        case searchBarTapped
        case courseButtonTapped
        case currentLocationTapped
        case retryTapped
        case dismissToast
        case searchResultsApplied(query: String, places: [Place])
        case searchClearTapped
        case searchBackTapped
        case bookmarkTapped(String)
        /// 별칭 시트가 저장한 뒤 목록을 갈아 끼운다
        case aliasSaved(id: String, alias: String)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 핀·행 탭. 흐름이 상세 시트를 연다
            case placeDetailRequested(String)
            /// 검색바 탭. 받는 쪽은 Cycle 3 이다
            case searchRequested
            case searchReopenRequested(query: String)
            /// `데이트 코스 짜러가기`. 받는 쪽은 Cycle 4 다
            case courseRequested
            /// 행 메뉴 수정. 흐름이 별칭 시트를 연다
            case aliasRequested(String)
            case deleteRequested(String)
            /// 세션 만료. RootFlow 까지 올라가 로그인으로 되돌린다
            case sessionExpired
        }
    }

    private enum CancelID {
        case load
        case couple
    }

    @Dependency(\.placeClient) var placeClient
    @Dependency(\.coupleClient) var coupleClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear, .retryTapped, .savedPlacesResponse, .coupleResponse:
            return load(state: &state, action: action)
        case .cameraChanged, .currentLocationTapped:
            return updateMap(state: &state, action: action)
        case .categoryTapped, .ownershipSelected, .rowMenuTapped, .rowMenuDismissed, .dismissToast:
            return updateFilter(state: &state, action: action)
        case .editTapped, .deleteTapped, .markerTapped, .rowTapped, .searchBarTapped, .courseButtonTapped:
            return raise(state: &state, action: action)
        case .searchResultsApplied, .searchClearTapped, .searchBackTapped, .bookmarkTapped:
            return updateSearch(state: &state, action: action)
        case .aliasSaved:
            return applyAlias(state: &state, action: action)
        case .delegate:
            return .none
        }
    }

    private func load(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.loadState = .loading
            return .merge(loadPlaces(), loadCouple())

        case .retryTapped:
            state.loadState = .loading
            state.toast = nil
            // 커플 조회도 같이 다시 부른다. 안 그러면 첫 조회가 실패했을 때
            // 저장자 필터를 되살릴 길이 없다
            return .merge(loadPlaces(), loadCouple())

        case let .savedPlacesResponse(.success(places)):
            state.places = places
            state.bookmarkedPlaceIDs = Set(places.map(\.id))
            state.loadState = .loaded
            return .none

        case let .savedPlacesResponse(.failure(error)):
            // 인증 만료만 상위로 올려 로그인으로 보낸다. 다시 시도해도 안 풀리는 실패다
            if error == .unauthorized {
                // 위에서 화면을 안 바꿔주면 시트가 로딩 뼈대에 갇힌다. 먼저 실패로 세운다
                state.loadState = .failed
                return .send(.delegate(.sessionExpired))
            }
            state.loadState = .failed
            state.toast = ToastState(
                message: "장소를 불러오지 못했어요",
                icon: .error,
                actionTitle: "다시 시도"
            )
            return .none

        case let .coupleResponse(isConnected):
            state.isCoupleConnected = isConnected
            // 연동이 풀린 채로 저장자 필터가 남아 있으면 목록이 이유 없이 좁아진다
            if !isConnected {
                state.selectedOwnership = .together
            }
            return .none

        default:
            // core 가 이 묶음으로 안 보내는 액션이라 도달하지 않는다.
            // 새 액션을 묶음에 넣고 여기 처리를 빠뜨리면 개발 빌드에서 바로 터진다
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    private func updateMap(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .cameraChanged(camera):
            state.camera = camera
            return .none

        case .currentLocationTapped:
            // 현재위치 권한과 추적은 이 사이클 밖이다. 카메라를 기본 자리로 되돌린다
            state.camera = .ansan
            return .none

        default:
            // core 가 이 묶음으로 안 보내는 액션이라 도달하지 않는다.
            // 새 액션을 묶음에 넣고 여기 처리를 빠뜨리면 개발 빌드에서 바로 터진다
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    private func updateFilter(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .categoryTapped(category):
            // 같은 칩을 다시 누르면 선택이 풀려 전체로 돌아간다
            state.selectedCategory = (state.selectedCategory == category) ? nil : category
            return .none

        case let .ownershipSelected(filter):
            state.selectedOwnership = filter
            return .none

        case let .rowMenuTapped(id):
            state.menuTargetPlaceID = (state.menuTargetPlaceID == id) ? nil : id
            return .none

        case .rowMenuDismissed:
            state.menuTargetPlaceID = nil
            return .none

        case .dismissToast:
            state.toast = nil
            return .none

        default:
            // core 가 이 묶음으로 안 보내는 액션이라 도달하지 않는다.
            // 새 액션을 묶음에 넣고 여기 처리를 빠뜨리면 개발 빌드에서 바로 터진다
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    /// 이 Scene 밖이 받는 신호는 `delegate` 로 올린다
    private func raise(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .editTapped(id):
            state.menuTargetPlaceID = nil
            return .send(.delegate(.aliasRequested(id)))

        case let .deleteTapped(id):
            state.menuTargetPlaceID = nil
            return .send(.delegate(.deleteRequested(id)))

        case let .markerTapped(id):
            // 상세로 넘어가는 길이다. 열린 팝오버를 두면 상세 시트 뒤에 남는다
            state.menuTargetPlaceID = nil
            // 선택 핀 id 는 목록에 없다. 다시 찾으면 상세가 닫히거나 엉뚱한 장소가 열린다
            guard id != State.selectedMarkerID else {
                return .none
            }
            return .send(.delegate(.placeDetailRequested(id)))

        case let .rowTapped(id):
            state.menuTargetPlaceID = nil
            return .send(.delegate(.placeDetailRequested(id)))

        case .searchBarTapped:
            return .send(.delegate(.searchRequested))

        case .courseButtonTapped:
            return .send(.delegate(.courseRequested))

        default:
            // core 가 이 묶음으로 안 보내는 액션이라 도달하지 않는다.
            // 새 액션을 묶음에 넣고 여기 처리를 빠뜨리면 개발 빌드에서 바로 터진다
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    private func loadPlaces() -> Effect<Action> {
        .run { [placeClient] send in
            do {
                await send(.savedPlacesResponse(.success(try await placeClient.savedPlaces())))
            } catch let error as PlaceError {
                await send(.savedPlacesResponse(.failure(error)))
            } catch {
                // PlaceError 가 아닌 것을 network 로 부르면 원인을 잘못 이름 붙인다
                await send(.savedPlacesResponse(.failure(.unknown)))
            }
        }
        // 탭을 오가며 여러 번 들어오면 늦게 온 옛 응답이 새 응답을 덮는다
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    private func loadCouple() -> Effect<Action> {
        .run { [coupleClient] send in
            // 커플 조회가 실패해도 목록은 그대로 뜬다. 저장자 칩만 안 보인다
            let status = try? await coupleClient.current()
            await send(.coupleResponse(status?.connected == true))
        }
        .cancellable(id: CancelID.couple, cancelInFlight: true)
    }
}

private extension MapFeature {
    func updateSearch(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .searchResultsApplied(query, places):
            state.mode = .searchResult(query: query, places: places)
            state.menuTargetPlaceID = nil
            if let first = places.first {
                state.camera.center = first.coordinate
            }
            return .none
        case .searchClearTapped:
            state.mode = .saved
            return .none
        case .searchBackTapped:
            guard let query = state.searchQuery else { return .none }
            return .send(.delegate(.searchReopenRequested(query: query)))
        case let .bookmarkTapped(id):
            if state.bookmarkedPlaceIDs.contains(id) {
                state.bookmarkedPlaceIDs.remove(id)
            } else {
                state.bookmarkedPlaceIDs.insert(id)
            }
            return .none
        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func applyAlias(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .aliasSaved(id, alias):
            // 서버에 별칭 수정 계약이 없다. 목록을 화면 안에서 갈아 끼운다
            if let index = state.places.firstIndex(where: { $0.id == id }) {
                let old = state.places[index]
                state.places[index] = SavedPlace(
                    place: old.place,
                    ownership: old.ownership,
                    alias: alias,
                    memo: old.memo,
                    savedAt: old.savedAt
                )
            }
            state.toast = ToastState(message: "별칭을 저장했어요")
            return .none
        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }
}

public extension MapFeature.State {
    /// 선택 핀 전용 id. 장소 목록에 없는 값이라 탭해도 상세를 다시 찾지 않는다
    static let selectedMarkerID = "map.selected"

    var markers: [MapMarker] {
        var markers: [MapMarker]
        switch mode {
        case .saved:
            markers = filteredPlaces.map { categoryMarker($0.place) }
        case let .searchResult(_, places):
            markers = places.map(categoryMarker)
        }
        // 고른 장소의 기존 핀은 지우지 않는다. 시안처럼 그 위에 선택 핀을 얹는다
        if let selectedPlace {
            markers.append(
                MapMarker(
                    id: Self.selectedMarkerID,
                    coordinate: selectedPlace.coordinate,
                    kind: .selected
                )
            )
        }
        return markers
    }

    private func categoryMarker(_ place: Place) -> MapMarker {
        MapMarker(
            id: place.id,
            coordinate: place.coordinate,
            kind: .category(place.category)
        )
    }

    var isSearching: Bool {
        if case .searchResult = mode { return true }
        return false
    }

    var searchQuery: String? {
        if case let .searchResult(query, _) = mode { return query }
        return nil
    }

    var searchResults: [Place] {
        if case let .searchResult(_, places) = mode { return places }
        return []
    }

    func isBookmarked(_ placeID: String) -> Bool {
        bookmarkedPlaceIDs.contains(placeID)
    }
}
