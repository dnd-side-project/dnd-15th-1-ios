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
        public var camera: MapCamera = .ansan
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

        /// 지도 핀과 시트 목록이 함께 보는 하나의 배열이다. 둘이 어긋날 수 없다
        public var filteredPlaces: [SavedPlace] {
            places
                .filter { selectedOwnership.matches($0.ownership) }
                .filter { selectedCategory == nil || $0.place.category == selectedCategory }
        }

        public var markers: [MapMarker] {
            filteredPlaces.map { saved in
                MapMarker(
                    id: saved.id,
                    coordinate: saved.place.coordinate,
                    kind: .category(saved.place.category)
                )
            }
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
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 핀·행 탭. 받는 쪽은 Cycle 2 다
            case placeSelected(String)
            /// 검색바 탭. 받는 쪽은 Cycle 3 이다
            case searchRequested
            /// `데이트 코스 짜러가기`. 받는 쪽은 Cycle 4 다
            case courseRequested
            case editRequested(String)
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

    /// 받는 쪽이 이 Scene 밖이라 상태만 정리하고 `delegate` 로 올린다
    private func raise(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .editTapped(id):
            state.menuTargetPlaceID = nil
            return .send(.delegate(.editRequested(id)))

        case let .deleteTapped(id):
            state.menuTargetPlaceID = nil
            return .send(.delegate(.deleteRequested(id)))

        case let .markerTapped(id), let .rowTapped(id):
            // 상세로 넘어가는 길이다. 열린 팝오버를 두면 상세 시트 뒤에 남는다
            state.menuTargetPlaceID = nil
            return .send(.delegate(.placeSelected(id)))

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
