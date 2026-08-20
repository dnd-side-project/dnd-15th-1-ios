import ComposableArchitecture
import Domain
import Foundation

// MARK: - CourseFeature

@Reducer
public struct CourseFeature {

    /// 지금 열려 있는 휠 시트가 무엇인지.
    public enum WheelTarget: Equatable {
        case date
        case time
    }

    public enum LoadState: Equatable {
        case loading
        case loaded
        case failed
    }

    // MARK: State

    @ObservableState
    public struct State: Equatable {
        // 날짜 화면
        public var partnerNickname: String?
        public var date: DateComponents?
        public var time: DateComponents?
        public var showsDateError = false
        public var activeWheel: WheelTarget?
        /// 자정을 넘겨도 하한과 초기값이 다른 날을 가리키지 않게, 한 번 센 오늘을 같이 쓴다
        public var today: DateComponents
        /// 시트 안에서 굴리는 임시값. `확인` 을 눌러야 date/time 으로 넘어간다
        public var draftDate: DateComponents
        public var draftTime: DateComponents = Self.defaultTime

        // 장소 화면
        public var places: [SavedPlace] = []
        public var loadState: LoadState = .loading
        public var isCoupleConnected = false
        public var selectedOwnership: PlaceOwnership = .together
        public var selectedCategory: PlaceCategory?
        /// 순서가 곧 번호다. Set 을 쓰면 번호를 못 매긴다
        public var selectedPlaceIDs: [String] = []
        public var camera: MapCamera = .ansan

        public init() {
            let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            self.today = today
            self.draftDate = today
        }
    }

    // MARK: Action

    public enum Action: Equatable {
        case onAppear
        case savedPlacesResponse(Result<[SavedPlace], PlaceError>)
        case coupleResponse(CoupleStatus?)

        // 날짜 화면
        case dateFieldTapped
        case timeFieldTapped
        case wheelDraftChanged(DateComponents)
        case wheelConfirmed
        case wheelDismissed
        case nextTapped

        // 장소 화면
        case ownershipSelected(PlaceOwnership)
        case categoryTapped(PlaceCategory?)
        case rowTapped(String)
        case markerTapped(String)
        case cameraChanged(MapCamera)
        case buildTapped
        case retryTapped
        case backTapped

        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 날짜와 시간을 합치지 않고 그대로 올린다.
            /// 서버 명세가 없어 `Date` 로 만드는 자리를 Cycle 5 로 미룬다
            case buildRequested(date: DateComponents, time: DateComponents?, placeIDs: [String])
            case placePickRequested
            case dismissed
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
        case .dateFieldTapped, .timeFieldTapped, .wheelDraftChanged, .wheelConfirmed, .wheelDismissed, .nextTapped:
            return updateDate(state: &state, action: action)
        case .ownershipSelected, .categoryTapped, .rowTapped, .markerTapped, .cameraChanged:
            return updatePlace(state: &state, action: action)
        case .backTapped, .buildTapped:
            return raise(state: &state, action: action)
        case .delegate:
            return .none
        }
    }
}

// MARK: - Reduce

private extension CourseFeature {

    func load(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.loadState = .loading
            return .merge(loadPlaces(), loadCouple())

        case .retryTapped:
            state.loadState = .loading
            return loadPlaces()

        case let .savedPlacesResponse(.success(places)):
            state.places = places
            state.loadState = .loaded
            return .none

        case let .savedPlacesResponse(.failure(error)):
            state.loadState = .failed
            return error == .unauthorized ? .send(.delegate(.sessionExpired)) : .none

        case let .coupleResponse(status):
            state.partnerNickname = status?.partner?.nickname
            state.isCoupleConnected = status?.connected ?? false
            // 연동이 풀린 채로 저장자 필터가 남아 있으면 목록이 이유 없이 좁아진다
            if !state.isCoupleConnected {
                state.selectedOwnership = .together
            }
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func updateDate(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .dateFieldTapped:
            state.draftDate = state.date ?? state.draftDate
            state.activeWheel = .date
            return .none

        case .timeFieldTapped:
            state.draftTime = state.time ?? state.draftTime
            state.activeWheel = .time
            return .none

        case let .wheelDraftChanged(components):
            applyDraft(&state, components)
            return .none

        case .wheelConfirmed:
            confirmWheel(&state)
            return .none

        case .wheelDismissed:
            state.activeWheel = nil
            return .none

        case .nextTapped:
            guard state.date != nil else {
                state.showsDateError = true
                return .none
            }
            state.showsDateError = false
            return .send(.delegate(.placePickRequested))

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func updatePlace(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .ownershipSelected(ownership):
            state.selectedOwnership = ownership
            return .none

        case let .categoryTapped(category):
            // 같은 값 재탭은 해제로 읽는다. 지도 탭과 같은 규칙이다
            state.selectedCategory = state.selectedCategory == category ? nil : category
            return .none

        case .rowTapped(let id), .markerTapped(let id):
            toggle(&state, id: id)
            return .none

        case let .cameraChanged(camera):
            state.camera = camera
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func raise(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .backTapped:
            return .send(.delegate(.dismissed))

        case .buildTapped:
            guard let date = state.date, !state.selectedPlaceIDs.isEmpty else { return .none }
            return .send(
                .delegate(
                    .buildRequested(
                        date: date,
                        time: state.time,
                        placeIDs: state.selectedPlaceIDs
                    )
                )
            )

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func loadPlaces() -> Effect<Action> {
        .run { [placeClient] send in
            do {
                let places = try await placeClient.savedPlaces()
                await send(.savedPlacesResponse(.success(places)))
            } catch let error as PlaceError {
                await send(.savedPlacesResponse(.failure(error)))
            } catch {
                await send(.savedPlacesResponse(.failure(.unknown)))
            }
        }
        // 두 화면이 각각 onAppear 를 보내면 늦게 온 옛 응답이 새 응답을 덮는다
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    /// 커플 조회가 실패해도 화면은 뜬다. 제목만 한 줄로 줄어든다
    func loadCouple() -> Effect<Action> {
        .run { [coupleClient] send in
            let status = try? await coupleClient.current()
            await send(.coupleResponse(status))
        }
        .cancellable(id: CancelID.couple, cancelInFlight: true)
    }

    func applyDraft(_ state: inout State, _ components: DateComponents) {
        switch state.activeWheel {
        case .date: state.draftDate = components
        case .time: state.draftTime = components
        case .none: break
        }
    }

    func confirmWheel(_ state: inout State) {
        switch state.activeWheel {
        case .date:
            state.date = state.draftDate
            state.showsDateError = false
        case .time:
            state.time = state.draftTime
        case .none:
            break
        }
        state.activeWheel = nil
    }

    func toggle(_ state: inout State, id: String) {
        let placeID = CourseMarkerID.placeID(from: id)
        if let index = state.selectedPlaceIDs.firstIndex(of: placeID) {
            state.selectedPlaceIDs.remove(at: index)
        } else {
            state.selectedPlaceIDs.append(placeID)
        }
    }
}

// MARK: - Marker ID

/// 물방울 핀 id. 카테고리 핀과 같은 장소 id 를 쓰면 지도가 하나를 버린다
private enum CourseMarkerID {
    static let candidatePrefix = "candidate:"

    static func candidate(_ placeID: String) -> String {
        candidatePrefix + placeID
    }

    static func placeID(from markerID: String) -> String {
        guard markerID.hasPrefix(candidatePrefix) else { return markerID }
        return String(markerID.dropFirst(candidatePrefix.count))
    }
}

// MARK: - Derived

public extension CourseFeature.State {

    var filteredPlaces: [SavedPlace] {
        places
            .filter { selectedOwnership.matches($0.ownership) }
            .filter { selectedCategory == nil || $0.place.category == selectedCategory }
    }

    /// 카테고리 핀을 먼저 두고 고른 물방울을 뒤에 둔다. 지도가 배열 순서로 그려 물방울이 위에 온다
    var markers: [MapMarker] {
        let selected = Set(selectedPlaceIDs)
        let categoryPins = filteredPlaces
            .map { saved in
                MapMarker(
                    id: saved.id,
                    coordinate: saved.place.coordinate,
                    kind: .category(saved.place.category)
                )
            }
        // 고른 물방울은 필터를 타지 않는다. 목록에서 사라져도 핀으로 해제할 수 있어야 한다
        let candidatePins = places
            .filter { selected.contains($0.id) }
            .map { saved in
                MapMarker(
                    id: CourseMarkerID.candidate(saved.id),
                    coordinate: saved.place.coordinate,
                    kind: .candidate
                )
            }
        return categoryPins + candidatePins
    }

    var selectedCount: Int { selectedPlaceIDs.count }

    var ctaTitle: String {
        selectedCount == 0 ? "장소를 선택해주세요" : "\(selectedCount)곳으로 코스짜기"
    }

    var isCTAEnabled: Bool { selectedCount >= 1 }

    var isEmpty: Bool { loadState == .loaded && filteredPlaces.isEmpty }

    var hasNoSavedPlace: Bool { loadState == .loaded && places.isEmpty }

    /// `2026.08.05`
    var dateText: String? {
        guard let date, let year = date.year, let month = date.month, let day = date.day else {
            return nil
        }
        return String(format: "%04d.%02d.%02d", year, month, day)
    }

    /// `오후 1:00`
    var timeText: String? {
        guard let time, let hour = time.hour, let minute = time.minute else { return nil }
        let isMorning = hour < 12
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%@ %d:%02d", isMorning ? "오전" : "오후", hour12, minute)
    }
}

// MARK: - Badge

public extension CourseFeature.State {

    func badgeState(for id: String) -> PlaceNumberBadgeState {
        guard let index = selectedPlaceIDs.firstIndex(of: id) else { return .unselected }
        return .number(index + 1)
    }
}

// MARK: - Default

private extension CourseFeature.State {

    /// 시안 b03·c10 이 `오후 1:00` 을 보인다
    static var defaultTime: DateComponents {
        DateComponents(hour: 13, minute: 0)
    }
}
