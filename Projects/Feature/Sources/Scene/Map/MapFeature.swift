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
            case saved
            case searchResult(query: String, places: [Place])
            /// 게시글 상세가 올린 장소들. 검색 UI 없이 핀만 얹는다
            case content(places: [Place])
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

        public var camera: MapCamera = .seoulCityHall
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

        /// 위치 권한이 거부된 채로 현재위치를 눌렀을 때 뜨는 설정 이동 안내
        public var isLocationPermissionModalPresented = false

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
        case filtersReset
        case rowMenuTapped(String)
        case rowMenuDismissed
        case editTapped(String)
        case deleteTapped(String)
        case markerTapped(String)
        case rowTapped(String)
        case searchBarTapped
        case courseButtonTapped
        case currentLocationTapped
        case locationAuthorizationResponse(LocationAuthorization)
        case currentLocationResponse(Result<Coordinate, LocationError>)
        case permissionModalDismissed
        case retryTapped
        case dismissToast
        case searchResultsApplied(query: String, places: [Place])
        case contentPlacesApplied(places: [Place])
        case searchClearTapped
        case searchBackTapped
        case bookmarkTapped(String)
        /// 별칭 시트가 저장한 뒤 목록을 갈아 끼운다
        case aliasSaved(SavedPlace)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 핀·행 탭. 흐름이 상세 시트를 연다
            case placeDetailRequested(String)
            /// 검색바 탭
            case searchRequested
            case searchReopenRequested(query: String)
            /// `데이트 코스 짜러가기`
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
        case location
    }

    @Dependency(\.placeClient) var placeClient
    @Dependency(\.coupleClient) var coupleClient
    @Dependency(\.locationClient) var locationClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear, .retryTapped, .savedPlacesResponse, .coupleResponse:
            return load(state: &state, action: action)
        case .cameraChanged, .currentLocationTapped,
             .locationAuthorizationResponse, .currentLocationResponse, .permissionModalDismissed:
            return updateMap(state: &state, action: action)
        case .categoryTapped, .ownershipSelected, .filtersReset, .rowMenuTapped, .rowMenuDismissed, .dismissToast:
            return updateFilter(state: &state, action: action)
        case .editTapped, .deleteTapped, .markerTapped, .rowTapped, .searchBarTapped, .courseButtonTapped:
            return raise(state: &state, action: action)
        case .searchResultsApplied, .contentPlacesApplied, .searchClearTapped, .searchBackTapped, .bookmarkTapped:
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
            // 게시글 핀·선택 장소를 보고 있을 땐 저장 목록 로딩이 카메라를 뺏지 않게 한다
            if case .saved = state.mode, state.selectedPlace == nil {
                state.camera = Self.overview(of: state)
            }
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

    private func updateFilter(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .categoryTapped(category):
            // 같은 칩을 다시 누르면 선택이 풀려 전체로 돌아간다
            state.selectedCategory = (state.selectedCategory == category) ? nil : category
            // 남은 목록의 첫 행으로 옮긴다. 실기기에서 어색하면 이 줄만 지운다 (2026-08-21 결정)
            state.camera = Self.overview(of: state)
            return .none

        case let .ownershipSelected(filter):
            state.selectedOwnership = filter
            // 카테고리 필터와 같은 규칙이다. 안 옮기면 화면 한가운데 장소가 목록에서 사라진다
            state.camera = Self.overview(of: state)
            return .none

        case .filtersReset:
            // 홈 전체보기로 들어올 때 걸린 필터를 기본으로 되돌리고 전체를 비춘다
            state.selectedCategory = nil
            state.selectedOwnership = .together
            state.camera = Self.overview(of: state)
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
            if let coordinate = Self.coordinate(of: id, in: state) {
                state.camera = .focusing(coordinate, zoomLevel: state.camera.zoomLevel)
            }
            return .send(.delegate(.placeDetailRequested(id)))

        case let .rowTapped(id):
            state.menuTargetPlaceID = nil
            if let coordinate = Self.coordinate(of: id, in: state) {
                // 상세로 들어가는 길이다. 확대하면 보던 지도가 달라져 방향을 잃는다 (2026-08-21 결정)
                state.camera = .focusing(coordinate, zoomLevel: state.camera.zoomLevel)
            }
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
    func updateMap(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .cameraChanged(camera):
            state.camera = camera
            return .none

        case .currentLocationTapped:
            return .run { [locationClient] send in
                await send(.locationAuthorizationResponse(locationClient.authorization()))
            }
            .cancellable(id: CancelID.location, cancelInFlight: true)

        case let .locationAuthorizationResponse(status):
            switch status {
            case .notDetermined:
                return .run { [locationClient] send in
                    let decided = await locationClient.requestAuthorization()
                    // 방금 거부를 누른 사람에게 곧바로 설정 이동을 조르지 않는다.
                    // 안내는 다음번에 버튼을 누를 때 뜬다
                    guard decided == .authorized else { return }
                    await Self.sendCoordinate(using: locationClient, to: send)
                }
                .cancellable(id: CancelID.location, cancelInFlight: true)

            case .authorized:
                return .run { [locationClient] send in
                    await Self.sendCoordinate(using: locationClient, to: send)
                }
                .cancellable(id: CancelID.location, cancelInFlight: true)

            case .denied:
                state.isLocationPermissionModalPresented = true
                return .none
            }

        case let .currentLocationResponse(.success(coordinate)):
            // 오프셋은 안 건다. 화면 어디에 놓을지는 `DulpickMapView` 가 정한다
            state.camera = .focusing(coordinate, zoomLevel: MapCamera.singlePlaceZoom)
            return .none

        case .currentLocationResponse(.failure):
            // 실패는 종류를 안 가린다. 조회 도중 권한이 사라지는 경우는 드물고,
            // 그때 모달을 띄우면 누른 적 없는 화면이 갑자기 뜬다
            state.toast = ToastState.error("현재 위치를 찾지 못했어요")
            return .none

        case .permissionModalDismissed:
            state.isLocationPermissionModalPresented = false
            return .none

        default:
            // core 가 이 묶음으로 안 보내는 액션이라 도달하지 않는다.
            // 새 액션을 묶음에 넣고 여기 처리를 빠뜨리면 개발 빌드에서 바로 터진다
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    /// 좌표를 한 번 읽어 결과 액션으로 보낸다. 미결정 갈래와 허용 갈래가 같이 쓴다
    static func sendCoordinate(
        using locationClient: LocationClient,
        to send: Send<Action>
    ) async {
        do {
            let coordinate = try await locationClient.currentCoordinate()
            await send(.currentLocationResponse(.success(coordinate)))
        } catch {
            await send(.currentLocationResponse(.failure(error as? LocationError ?? .unavailable)))
        }
    }

    func updateSearch(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .searchResultsApplied(query, places):
            state.mode = .searchResult(query: query, places: places)
            state.menuTargetPlaceID = nil
            if let first = places.first {
                state.camera = .focusing(first.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
            }
            return .none
        case let .contentPlacesApplied(places):
            state.mode = .content(places: places)
            state.menuTargetPlaceID = nil
            // 카메라는 맨 첫 장소를 가운데로 고정한다
            if let first = places.first {
                state.camera = .focusing(first.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
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
        case let .aliasSaved(savedPlace):
            if let index = state.places.firstIndex(where: { $0.id == savedPlace.id }) {
                state.places[index] = savedPlace
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
        case let .content(places):
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

    /// 게시글 핀 모드 여부. 이때는 지도 검색·필터 UI 를 감춘다
    var isContentMode: Bool {
        if case .content = mode { return true }
        return false
    }

    /// 저장 시트·코스 버튼 표시 여부.
    /// 장소를 고르면(상세) 감추고, 게시글 핀 모드에선 상세가 덮으므로 통째로 감춘다
    var showsSavedSheet: Bool {
        if case .content = mode { return false }
        return selectedPlace == nil
    }

    var searchQuery: String? {
        if case let .searchResult(query, _) = mode { return query }
        return nil
    }

    var searchResults: [Place] {
        if case let .searchResult(_, places) = mode { return places }
        return []
    }

    /// 게시글 핀 모드에서 지도에 얹힌 장소들. 핀 탭으로 상세를 열 때 여기서 찾는다
    var contentPlaces: [Place] {
        if case let .content(places) = mode { return places }
        return []
    }

    func isBookmarked(_ placeID: String) -> Bool {
        bookmarkedPlaceIDs.contains(placeID)
    }
}

private extension MapFeature {

    /// 여러 장소를 보는 자리. 첫 행이 없으면 서울 시청이다
    static func overview(of state: State) -> MapCamera {
        guard let first = state.filteredPlaces.first else { return .seoulCityHall }
        return .focusing(first.place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
    }

    /// 검색 결과와 저장 목록 어느 쪽에서든 그 id 의 좌표를 찾는다
    static func coordinate(of id: String, in state: State) -> Coordinate? {
        if let place = state.searchResults.first(where: { $0.id == id }) {
            return place.coordinate
        }
        if let place = state.contentPlaces.first(where: { $0.id == id }) {
            return place.coordinate
        }
        return state.places.first { $0.id == id }?.place.coordinate
    }
}
