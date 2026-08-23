import ComposableArchitecture
import Domain
import Foundation
import SharedDesignSystem

// MARK: - CourseResultFeature

@Reducer
public struct CourseResultFeature {

    /// 이 분을 넘는 구간에 `이동이 긴 구간입니다` 를 붙인다.
    /// 시안 `c02` 는 20분에 안 붙고 1시간 20분에 붙는다. 그 사이를 30분으로 잡았다
    public static let longLegMinutes = 30

    public enum LoadState: Equatable {
        case loading
        case loaded
        case failed
    }

    // MARK: State

    @ObservableState
    public struct State: Equatable {
        /// 이 화면에 어디서 들어왔는지. 지난 데이트면 수정·알리기를 안 낸다.
        /// `status` 로 대신하면 안 된다. 지난 데이트도 `CONFIRMED` 라 예정 데이트와 구별이 안 된다
        public enum Origin: Equatable {
            /// 코스를 짜서 저장한 직후, 또는 예정 데이트
            case courseBuilt
            /// 지난 데이트 목록에서 열었다
            case pastDate
        }

        /// 앞 화면이 넘겨준 코스. 재진입이면 nil 로 시작한다
        public var course: DateCourse?
        public var dateCourseID: String
        public var partnerNickname: String?
        public var origin: Origin
        public var loadState: LoadState
        public var camera: MapCamera = .seoulCityHall
        public var hasUserMovedCamera = false
        public var isNotifyingPartner = false
        public var toast: ToastState?

        public init(
            course: DateCourse?,
            dateCourseID: String,
            partnerNickname: String? = nil,
            origin: Origin = .courseBuilt
        ) {
            self.course = course
            self.dateCourseID = dateCourseID
            self.partnerNickname = partnerNickname
            self.origin = origin
            self.loadState = course == nil ? .loading : .loaded
        }
    }

    // MARK: Action

    public enum Action: Equatable {
        case onAppear
        case reloadRequested
        case courseResponse(Result<DateCourse, CourseError>)
        case mapSizeChanged(width: CGFloat, visibleHeight: CGFloat)
        case cameraChanged(MapCamera)
        case notifyTapped
        case partnerNotified(CourseError?)
        case editTapped
        case backTapped
        case toastDismissed
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// `수정`
            case editRequested(DateCourse)
            /// 뒤로가기. 어디로 갈지는 이 화면이 안 정한다
            case dismissed
            case sessionExpired
        }
    }

    private enum CancelID {
        case load
        case notify
    }

    @Dependency(\.courseClient) var courseClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear, .reloadRequested, .courseResponse:
            return load(state: &state, action: action)
        case .mapSizeChanged, .cameraChanged:
            return updateMap(state: &state, action: action)
        case .notifyTapped, .partnerNotified, .toastDismissed:
            return notify(state: &state, action: action)
        case .editTapped, .backTapped:
            return raise(state: &state, action: action)
        case .delegate:
            return .none
        }
    }
}

// MARK: - Reduce

private extension CourseResultFeature {

    func load(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            guard state.course == nil else { return .none }
            state.loadState = .loading
            return fetchCourse(id: state.dateCourseID)

        case .reloadRequested:
            // 옛 코스를 둔 채 읽는다. 화면을 비우면 로딩이 깜빡인다
            return fetchCourse(id: state.dateCourseID)

        case let .courseResponse(.success(course)):
            state.course = course
            state.loadState = .loaded
            return .none

        case let .courseResponse(.failure(error)):
            if state.course == nil {
                state.loadState = .failed
            }
            guard error != .unauthorized else {
                return .send(.delegate(.sessionExpired))
            }
            if state.course != nil {
                state.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
            }
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func fetchCourse(id: String) -> Effect<Action> {
        .run { [courseClient] send in
            do {
                let course = try await courseClient.course(id)
                await send(.courseResponse(.success(course)))
            } catch let error as CourseError {
                await send(.courseResponse(.failure(error)))
            } catch {
                await send(.courseResponse(.failure(.unknown)))
            }
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    func updateMap(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .mapSizeChanged(width, visibleHeight):
            guard !state.hasUserMovedCamera else { return .none }
            let coordinates = state.stops.map(\.place.coordinate)
            guard let anchor = coordinates.first else { return .none }
            let zoom = MapZoom.fit(
                coordinates: coordinates,
                anchor: anchor,
                viewWidth: width,
                visibleHeight: visibleHeight,
                maximum: MapCamera.multiPlaceZoom,
                focusRatio: MapZoom.mapFocusRatio
            )
            state.camera = MapCamera(center: anchor, zoomLevel: zoom)
            return .none

        case let .cameraChanged(camera):
            state.camera = camera
            state.hasUserMovedCamera = true
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    func notify(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .notifyTapped:
            guard !state.isNotifyingPartner else { return .none }
            state.isNotifyingPartner = true
            let id = state.dateCourseID
            return .run { [courseClient] send in
                do {
                    try await courseClient.notifyPartner(id)
                    await send(.partnerNotified(nil))
                } catch let error as CourseError {
                    await send(.partnerNotified(error))
                } catch {
                    await send(.partnerNotified(.unknown))
                }
            }
            .cancellable(id: CancelID.notify, cancelInFlight: true)

        case .partnerNotified(nil):
            state.isNotifyingPartner = false
            state.toast = ToastState(message: "상대에게 코스를 알렸어요")
            return .none

        case let .partnerNotified(error?):
            state.isNotifyingPartner = false
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

    func raise(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .editTapped:
            guard let course = state.course else { return .none }
            return .send(.delegate(.editRequested(course)))

        case .backTapped:
            return .send(.delegate(.dismissed))

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }
}

// MARK: - Marker ID

/// 번호 물방울 핀 id. 카테고리 핀과 같은 장소 id 를 쓰면 지도가 하나를 버린다
private enum CourseResultMarkerID {
    static let numberedPrefix = "numbered:"

    static func numbered(_ placeID: String) -> String {
        numberedPrefix + placeID
    }
}

// MARK: - Derived

public extension CourseResultFeature.State {

    var stops: [Domain.CourseStop] { course?.stops ?? [] }

    /// 장소가 없으면 요약 줄이 없다
    var summaryText: String? {
        guard let course, !course.stops.isEmpty else { return nil }
        let duration = CourseResultText.duration(course.totalWalkingMinutes)
        let distance = CourseResultText.summaryDistance(course.totalDistanceMeters)
        return "\(course.stops.count)곳 · 도보 약 \(duration) · 총 이동 \(distance)"
    }

    /// 지난 데이트는 고칠 이유가 없다. 서버는 안 막으니 화면이 막는다
    var showsEditButton: Bool { origin != .pastDate }

    /// 장소가 없으면 알릴 것이 없고, 지난 데이트는 알릴 이유가 없다
    var showsNotifyButton: Bool {
        origin != .pastDate && !(course?.stops.isEmpty ?? true)
    }

    var notifyTitle: String {
        guard let nickname = partnerNickname else { return "상대에게 코스 알리기" }
        return "\(nickname)에게 코스 알리기"
    }

    var markers: [MapMarker] {
        stops.enumerated().flatMap { index, stop in
            [
                MapMarker(
                    id: stop.id,
                    coordinate: stop.place.coordinate,
                    kind: .category(stop.place.category)
                ),
                MapMarker(
                    id: CourseResultMarkerID.numbered(stop.id),
                    coordinate: stop.place.coordinate,
                    kind: .numbered(index + 1)
                ),
            ]
        }
    }

    var routes: [MapRoute] {
        guard stops.count >= 2 else { return [] }
        return [MapRoute(id: "course-\(dateCourseID)", coordinates: stops.map(\.place.coordinate))]
    }
}

extension CourseResultFeature.State {

    var timelineStops: [CourseStop] {
        stops.map { stop in
            CourseStop(
                id: stop.id,
                name: stop.place.name,
                category: stop.place.category.displayName,
                address: CourseResultText.address(of: stop.place)
            )
        }
    }

    var timelineLegs: [CourseLeg] {
        (course?.legs ?? []).map { (leg: Domain.CourseLeg?) in
            guard let leg else {
                return CourseLeg(duration: "", distance: "", isLong: false)
            }
            return CourseLeg(
                duration: "도보 \(CourseResultText.duration(leg.walkingMinutes))",
                distance: CourseResultText.legDistance(leg.distanceMeters),
                isLong: leg.walkingMinutes > CourseResultFeature.longLegMinutes
            )
        }
    }
}

// MARK: - Text

private enum CourseResultText {

    static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remain = minutes % 60
        if hours > 0, remain > 0 {
            return "\(hours)시간 \(remain)분"
        }
        if hours > 0 {
            return "\(hours)시간"
        }
        return "\(minutes)분"
    }

    static func summaryDistance(_ meters: Int) -> String {
        "\(kilometers(meters))km"
    }

    static func legDistance(_ meters: Int) -> String {
        "\(kilometers(meters)) km"
    }

    private static func kilometers(_ meters: Int) -> String {
        String(format: "%.1f", Double(meters) / 1_000)
    }

    static func address(of place: Place) -> String {
        place.roadAddress.isEmpty ? place.address : place.roadAddress
    }
}
