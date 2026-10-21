import ComposableArchitecture
import CoreKakaoMap
import Domain
import Foundation
import SharedDesignSystem
import SharedUtils

// MARK: - CourseFeature

@Reducer
public struct CourseFeature {

    /// 지금 열려 있는 휠 시트가 무엇인지.
    public enum WheelTarget: Equatable {
        case date
        case time
    }

    public enum Mode: Equatable, Sendable {
        case create
        /// 코스 수정의 「장소 추가」. 기존 코스 장소를 수정 화면의 저장 전 순서 그대로 받는다
        case pick(existing: [ExistingCoursePlace])
    }

    public enum LoadState: Equatable {
        case loading
        case loaded
        case failed
    }

    /// 목록을 이 행까지 올려 달라는 요청. 요청마다 번호가 하나씩 늘어 같은 행이어도 새 값이 된다
    public struct RowScrollRequest: Equatable, Sendable {
        public let placeID: String
        public let sequence: Int

        public init(placeID: String, sequence: Int) {
            self.placeID = placeID
            self.sequence = sequence
        }
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
        // 플래그가 먼저 내려가고, 퇴장이 끝난 뒤 activeWheel 을 비운다
        public var isWheelPresented = false
        /// 자정을 넘겨도 하한과 초기값이 다른 날을 가리키지 않게, 한 번 센 내일로 둔다
        public var tomorrow: DateComponents
        /// 시트 안에서 굴리는 임시값. `확인` 을 눌러야 date/time 으로 넘어간다
        public var draftDate: DateComponents
        public var draftTime: DateComponents
        public var mode: Mode
        /// POST /api/v1/date-courses 응답. 다음 화면이 들고 간다
        public var dateCourseID: String?
        /// 낙관적 락 번호. 서버 응답 값을 그대로 들고 다닌다
        public var version: Int?
        public var isCreatingCourse = false
        public var isSavingCourse = false
        public var toast: ToastState?
        /// 409 를 받은 뒤 최신 코스를 다시 읽었을 때 띄우는 짧은 알림
        public var conflictAlertMessage: String?

        // 장소 화면
        public var places: [SavedPlace] = []
        public var loadState: LoadState = .loading
        public var isCoupleConnected = false
        public var selectedOwnership: PlaceOwnership = .together
        public var selectedCategory: PlaceCategory?
        /// 순서가 곧 번호다. Set 을 쓰면 번호를 못 매긴다
        public var selectedPlaceIDs: [String] = []
        public var camera: MapCamera = .seoulCityHall
        /// 핀을 누르면 들어간다. 뷰가 받아 목록을 그 행까지 올린다
        public var rowScrollRequest: RowScrollRequest?

        public init(now: Date = Date(), mode: Mode = .create) {
            var seoul = Calendar(identifier: .gregorian)
            seoul.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
            let tomorrowDate = seoul.date(byAdding: .day, value: 1, to: now) ?? now
            let tomorrow = seoul.dateComponents([.year, .month, .day], from: tomorrowDate)
            let nowTime = Calendar.current.dateComponents([.hour, .minute], from: now)
            self.tomorrow = tomorrow
            self.draftDate = tomorrow
            self.draftTime = nowTime
            self.mode = mode
            // 기존 코스 핀은 불러오기와 상관없이 그려지므로 카메라도 처음부터 그 끝을 본다
            if case let .pick(existing) = mode, let last = existing.last {
                self.camera = .focusing(last.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
            }
        }
    }

    // MARK: Action

    public enum Action: Equatable {
        case onAppear
        case coursePlacesResponse(Result<[SavedPlace], CourseError>)
        case coupleResponse(CoupleStatus?)
        case courseCreated(Result<DateCourse, CourseError>)
        case courseSaved(Result<DateCourse, CourseError>)
        case conflictReloaded(Result<DateCourse, CourseError>)
        case toastDismissed
        case conflictAlertDismissed

        // 날짜 화면
        case dateFieldTapped
        case timeFieldTapped
        case wheelDraftChanged(DateComponents)
        case wheelConfirmed
        case wheelDismissed
        case wheelDismissFinished
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
            /// 확정 저장된 코스. 결과 화면이 받아 그린다
            case buildRequested(DateCourse)
            case placePickRequested(dateCourseID: String)
            case placesPicked([SavedPlace])
            case dismissed
            case sessionExpired
        }
    }

    private enum CancelID {
        case load
        case couple
        case createCourse
        case saveCourse
        case reloadCourse
    }

    @Dependency(\.courseClient) var courseClient
    @Dependency(\.coupleClient) var coupleClient
    @Dependency(\.analyticsClient) var analyticsClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear, .retryTapped, .coursePlacesResponse, .coupleResponse:
            return load(state: &state, action: action)
        case .dateFieldTapped, .timeFieldTapped, .wheelDraftChanged, .wheelConfirmed, .wheelDismissed,
             .wheelDismissFinished, .nextTapped, .courseCreated, .toastDismissed:
            return updateDate(state: &state, action: action)
        case .ownershipSelected, .categoryTapped, .rowTapped, .markerTapped, .cameraChanged:
            return updatePlace(state: &state, action: action)
        case .backTapped:
            return raise(state: &state, action: action)
        case .buildTapped, .courseSaved, .conflictReloaded, .conflictAlertDismissed:
            return save(state: &state, action: action)
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

        case let .coursePlacesResponse(.success(places)):
            state.places = places
            state.loadState = .loaded
            state.camera = Self.overview(of: state)
            return .none

        case let .coursePlacesResponse(.failure(error)):
            state.loadState = .failed
            return error == .unauthorized ? .send(.delegate(.sessionExpired)) : .none

        case let .coupleResponse(status):
            // nil 은 조회 실패다. 연결 안 됨과 같게 칩을 숨긴다
            if case let .connected(_, partner, _)? = status {
                state.partnerNickname = partner.nickname
                state.isCoupleConnected = true
            } else {
                state.partnerNickname = nil
                state.isCoupleConnected = false
            }
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
            state.isWheelPresented = true
            return .none

        case .timeFieldTapped:
            state.draftTime = state.time ?? state.draftTime
            state.activeWheel = .time
            state.isWheelPresented = true
            return .none

        case let .wheelDraftChanged(components):
            applyDraft(&state, components)
            return .none

        case .wheelConfirmed:
            confirmWheel(&state)
            return .none

        case .wheelDismissed:
            state.isWheelPresented = false
            return .none

        case .wheelDismissFinished:
            state.activeWheel = nil
            return .none

        case .nextTapped:
            return startCreateCourse(state: &state)

        case let .courseCreated(.success(course)):
            state.isCreatingCourse = false
            state.dateCourseID = course.id
            state.version = course.version
            return .send(.delegate(.placePickRequested(dateCourseID: course.id)))

        case let .courseCreated(.failure(error)):
            state.isCreatingCourse = false
            guard error != .unauthorized else {
                return .send(.delegate(.sessionExpired))
            }
            state.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
            return .none

        case .toastDismissed:
            state.toast = nil
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func startCreateCourse(state: inout State) -> Effect<Action> {
        guard let date = state.date else {
            state.showsDateError = true
            return .none
        }
        state.showsDateError = false

        state.isCreatingCourse = true
        let time = state.time

        let title = DateCourseTitle.make(date: date)

        return .merge(
            .run { [analyticsClient] _ in
                await analyticsClient.track(.courseScheduleCompleted)
            },
            .run { [courseClient] send in
                do {
                    let course = try await courseClient.createCourse(title, date, time)
                    await send(.courseCreated(.success(course)))
                } catch let error as CourseError {
                    await send(.courseCreated(.failure(error)))
                } catch {
                    await send(.courseCreated(.failure(.unknown)))
                }
            }
            .cancellable(id: CancelID.createCourse, cancelInFlight: true)
        )
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

        case let .rowTapped(placeID):
            let wasSelected = state.selectedPlaceIDs.contains(placeID)
            toggle(&state, placeID: placeID)
            if let candidate = state.places.first(where: { $0.id == placeID }) {
                focus(&state, on: candidate.place.coordinate)
            }
            return trackAdded(wasSelected: wasSelected)

        case let .markerTapped(markerID):
            return tapMarker(&state, markerID: markerID)

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
            // 장소 선택을 벗어나도 저장 응답이 결과를 열지 않게 끊는다
            state.isSavingCourse = false
            state.conflictAlertMessage = nil
            return .merge(
                .cancel(id: CancelID.saveCourse),
                .cancel(id: CancelID.reloadCourse),
                .send(.delegate(.dismissed))
            )

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func save(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .buildTapped:
            if case .pick = state.mode {
                let picked = state.selectedPlaceIDs.compactMap { id in
                    state.places.first { $0.id == id }
                }
                return .send(.delegate(.placesPicked(picked)))
            }
            return startSaveCourse(state: &state)

        case let .courseSaved(.success(course)):
            state.isSavingCourse = false
            // 낡은 값으로 다시 저장하지 않게 한다
            state.version = course.version
            return .send(.delegate(.buildRequested(course)))

        case let .courseSaved(.failure(error)):
            if error == .unauthorized {
                state.isSavingCourse = false
                return .send(.delegate(.sessionExpired))
            }
            if error == .conflict {
                guard let id = state.dateCourseID else {
                    state.isSavingCourse = false
                    state.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
                    return .none
                }
                // 그냥 재시도하지 않는다. 최신 코스를 읽고 사용자에게 알린다
                return reloadCourse(id: id)
            }
            state.isSavingCourse = false
            state.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
            return .none

        case let .conflictReloaded(.success(course)):
            state.isSavingCourse = false
            state.version = course.version
            state.conflictAlertMessage = "상대방이 코스를 먼저 바꿨어요. 다시 확인해주세요"
            return .none

        case let .conflictReloaded(.failure(error)):
            state.isSavingCourse = false
            guard error != .unauthorized else {
                return .send(.delegate(.sessionExpired))
            }
            state.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
            return .none

        case .conflictAlertDismissed:
            state.conflictAlertMessage = nil
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func startSaveCourse(state: inout State) -> Effect<Action> {
        guard let dateCourseID = state.dateCourseID,
              let version = state.version,
              let date = state.date,
              !state.selectedPlaceIDs.isEmpty,
              !state.isSavingCourse else {
            return .none
        }
        state.isSavingCourse = true

        let content = DateCourseContent(
            title: DateCourseTitle.make(date: date),
            date: Self.dateOnly(from: date),
            time: state.time,
            placeIDs: state.selectedPlaceIDs
        )

        return .merge(
            .run { [analyticsClient] _ in
                await analyticsClient.track(.courseCreated)
            },
            .run { [courseClient] send in
                do {
                    let course = try await courseClient.updateCourse(
                        dateCourseID,
                        content,
                        version
                    )
                    await send(.courseSaved(.success(course)))
                } catch let error as CourseError {
                    await send(.courseSaved(.failure(error)))
                } catch {
                    await send(.courseSaved(.failure(.unknown)))
                }
            }
            .cancellable(id: CancelID.saveCourse, cancelInFlight: true)
        )
    }

    func reloadCourse(id: String) -> Effect<Action> {
        .run { [courseClient] send in
            do {
                let course = try await courseClient.course(id)
                await send(.conflictReloaded(.success(course)))
            } catch let error as CourseError {
                await send(.conflictReloaded(.failure(error)))
            } catch {
                await send(.conflictReloaded(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.reloadCourse, cancelInFlight: true)
    }

    static func dateOnly(from date: DateComponents) -> Date {
        var midnight = date
        midnight.hour = 0
        midnight.minute = 0
        midnight.second = 0
        midnight.timeZone = TimeZone(identifier: "Asia/Seoul")
        return Calendar(identifier: .gregorian).date(from: midnight) ?? Date.distantPast
    }

    func loadPlaces() -> Effect<Action> {
        .run { [courseClient] send in
            do {
                let places = try await courseClient.coursePlaces()
                await send(.coursePlacesResponse(.success(places)))
            } catch let error as CourseError {
                await send(.coursePlacesResponse(.failure(error)))
            } catch {
                await send(.coursePlacesResponse(.failure(.unknown)))
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
        state.isWheelPresented = false
    }

    func toggle(_ state: inout State, placeID: String) {
        if let index = state.selectedPlaceIDs.firstIndex(of: placeID) {
            state.selectedPlaceIDs.remove(at: index)
        } else {
            state.selectedPlaceIDs.append(placeID)
        }
    }

    func tapMarker(_ state: inout State, markerID: String) -> Effect<Action> {
        switch CourseMarkerID.target(of: markerID) {
        case .existing:
            // 기존 코스 장소는 이 화면에서 고르거나 빼지 않는다
            return .none

        case let .candidate(placeID):
            let wasSelected = state.selectedPlaceIDs.contains(placeID)
            let isListed = state.filteredPlaces.contains { $0.id == placeID }
            toggle(&state, placeID: placeID)
            // 필터에 걸려 목록에 없는 장소는 빼기만 한다. 옮길 행이 없고, 빼면 그 자리에 핀도 안 남는다
            guard isListed else { return trackAdded(wasSelected: wasSelected) }
            let sequence = (state.rowScrollRequest?.sequence ?? 0) + 1
            state.rowScrollRequest = RowScrollRequest(placeID: placeID, sequence: sequence)
            return trackAdded(wasSelected: wasSelected)
        }
    }

    /// 지금 줌을 그대로 둔다
    func focus(_ state: inout State, on coordinate: Coordinate) {
        state.camera = .focusing(coordinate, zoomLevel: state.camera.zoomLevel)
    }

    /// 새로 담을 때만 담기 이벤트를 보낸다
    func trackAdded(wasSelected: Bool) -> Effect<Action> {
        guard !wasSelected else { return .none }
        return .run { [analyticsClient] _ in
            await analyticsClient.track(.placeAddedToCourse)
        }
    }
}

// MARK: - Marker ID

/// 핀 id. 같은 장소에 카테고리 핀과 숫자 핀이 함께 서서 앞붙이로 가른다. 같은 id 면 지도가 하나를 버린다
private enum CourseMarkerID {
    enum Target: Equatable {
        /// 저장한 장소. 이 화면에서 고르거나 뺀다
        case candidate(String)
        /// 기존 코스 장소. 눌러도 아무 일도 없다
        case existing
    }

    static let numberedPrefix = "numbered:"
    static let existingCategoryPrefix = "existing:"
    static let existingNumberedPrefix = "existing-numbered:"

    static func numbered(_ placeID: String) -> String {
        numberedPrefix + placeID
    }

    static func existingCategory(_ placeID: String) -> String {
        existingCategoryPrefix + placeID
    }

    static func existingNumbered(_ placeID: String) -> String {
        existingNumberedPrefix + placeID
    }

    static func target(of markerID: String) -> Target {
        if markerID.hasPrefix(existingNumberedPrefix) || markerID.hasPrefix(existingCategoryPrefix) {
            return .existing
        }
        return .candidate(strip(numberedPrefix, from: markerID) ?? markerID)
    }

    private static func strip(_ prefix: String, from markerID: String) -> String? {
        guard markerID.hasPrefix(prefix) else { return nil }
        return String(markerID.dropFirst(prefix.count))
    }
}

// MARK: - Derived

public extension CourseFeature.State {

    /// 장소 추가로 들어왔을 때 기존 코스 장소. 저장 전 순서 그대로다
    var existingPlaces: [ExistingCoursePlace] {
        if case let .pick(existing) = mode { return existing }
        return []
    }

    var filteredPlaces: [SavedPlace] {
        let taken = Set(existingPlaces.map(\.id))
        return places
            .filter { selectedOwnership.matches($0.ownership) }
            .filter { selectedCategory == nil || $0.place.category == selectedCategory }
            .filter { !taken.contains($0.id) }
    }

    /// 기존 코스 핀, 목록의 카테고리 핀, 고른 숫자 핀 순서다.
    /// 겹침은 배열 순서가 아니라 핀 종류가 정한다. 숫자 핀이 카테고리 핀 위에 앉는다 (`MapMarkerStyle.rank(for:)`)
    var markers: [MapMarker] {
        let existingPins = existingPlaces.enumerated().flatMap { index, stop in
            [
                MapMarker(
                    id: CourseMarkerID.existingCategory(stop.id),
                    coordinate: stop.coordinate,
                    kind: .category(stop.category)
                ),
                MapMarker(
                    id: CourseMarkerID.existingNumbered(stop.id),
                    coordinate: stop.coordinate,
                    kind: .numbered(index + 1)
                ),
            ]
        }
        let categoryPins = filteredPlaces.map { candidate in
            MapMarker(
                id: candidate.id,
                coordinate: candidate.place.coordinate,
                kind: .category(candidate.place.category)
            )
        }
        // 숫자 핀은 필터를 타지 않는다. 목록에서 사라져도 핀으로 뺄 수 있어야 한다
        let numberedPins = selectedPlaceIDs.enumerated().compactMap { index, placeID -> MapMarker? in
            guard let candidate = places.first(where: { $0.id == placeID }) else { return nil }
            return MapMarker(
                id: CourseMarkerID.numbered(candidate.id),
                coordinate: candidate.place.coordinate,
                kind: .numbered(existingPlaces.count + index + 1)
            )
        }
        return existingPins + categoryPins + numberedPins
    }

    /// 기존 코스 다음에 고른 순서대로 잇는 직선. 점이 둘 이상일 때만 긋는다
    var routes: [MapRoute] {
        let picked = selectedPlaceIDs.compactMap { placeID in
            places.first { $0.id == placeID }?.place.coordinate
        }
        let coordinates = existingPlaces.map(\.coordinate) + picked
        guard coordinates.count >= 2 else { return [] }
        return [MapRoute(id: "course-pick", coordinates: coordinates)]
    }

    var selectedCount: Int { selectedPlaceIDs.count }

    var ctaTitle: String {
        if case .pick = mode {
            return "추가"
        }
        return selectedCount == 0 ? "장소를 선택해주세요" : "\(selectedCount)곳으로 코스짜기"
    }

    var isCTAEnabled: Bool { selectedCount >= 1 && !isSavingCourse }

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
        // 장소 추가에서는 기존 코스 뒤에 붙으므로 그 다음 번호부터 센다
        return .number(existingPlaces.count + index + 1)
    }
}

private extension CourseFeature {

    /// 여러 장소를 보는 자리. 장소 추가면 새 장소가 이어 붙을 기존 코스의 끝, 아니면 첫 행, 둘 다 없으면 서울 시청이다
    static func overview(of state: State) -> MapCamera {
        if let last = state.existingPlaces.last {
            return .focusing(last.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
        guard let first = state.filteredPlaces.first else { return .seoulCityHall }
        return .focusing(first.place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
    }
}
