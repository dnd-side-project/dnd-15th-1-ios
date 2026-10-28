import ComposableArchitecture
import CoreKakaoMap
import Domain
import Foundation
import SharedDesignSystem
import SharedUtils

// MARK: - CourseResultFeature

@Reducer
public struct CourseResultFeature {

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
        /// 내 위치 점. 위치 흐름만 채운다
        public var userLocation: Coordinate?

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
        case conflictReloadRequested
        case courseResponse(Result<DateCourse, CourseError>)
        case mapSizeChanged(width: CGFloat, visibleHeight: CGFloat)
        case cameraChanged(MapCamera)
        /// 지도가 화면에 나타났다. 내 위치 흐름을 연다. 지도가 사라지면 뷰의 task 취소로 끊긴다
        case mapAppeared
        case userLocationChanged(Coordinate?)
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
        case userLocation
    }

    @Dependency(\.courseClient) var courseClient
    @Dependency(\.analyticsClient) var analyticsClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.locationClient) var locationClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear, .reloadRequested, .conflictReloadRequested, .courseResponse:
            return load(state: &state, action: action)
        case .mapSizeChanged, .cameraChanged:
            return updateMap(state: &state, action: action)
        case .notifyTapped, .partnerNotified, .toastDismissed:
            return notify(state: &state, action: action)
        case .editTapped, .backTapped:
            return raise(state: &state, action: action)
        case .mapAppeared, .userLocationChanged:
            return updateUserLocation(state: &state, action: action)
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

        case .conflictReloadRequested:
            state.course = nil
            state.loadState = .loading
            state.toast = ToastState(message: "상대방이 먼저 바꿔서 최신 코스를 불러왔어요")
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
            // 경로 선이 장소 바깥으로 돌아도 잘리지 않게 선 좌표까지 담는다
            let coordinates = state.routeCoordinates
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
            return .merge(
                .run { [analyticsClient, authClient] _ in
                    let userID = (try? await authClient.currentSession())?.userID
                    await analyticsClient.track(.courseAlarmStarted(userID: userID))
                },
                .run { [courseClient] send in
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
            )

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
            return .merge(
                .run { [analyticsClient] _ in
                    await analyticsClient.track(.courseEditStarted)
                },
                .send(.delegate(.editRequested(course)))
            )

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

    /// 장소가 없으면 요약 줄이 없다.
    /// 숫자는 구간 행에 보이는 값의 합이다. 사용자가 화면에서 직접 맞춰 볼 수 있는 숫자다
    var summaryText: String? {
        guard let course, !course.stops.isEmpty else { return nil }
        let legs = course.legs.compactMap(\.self)
        let minutes = legs.reduce(0) { $0 + $1.travelMinutes }
        let tenths = legs.reduce(0) { $0 + CourseResultText.tenthsOfKilometer($1.travelDistanceMeters) }
        let duration = CourseResultText.duration(minutes)
        let distance = CourseResultText.summaryDistance(tenths: tenths)
        // 대중교통이 섞인 시간을 「도보」 라 부르지 않고, 「이동」 을 한 줄에 두 번 쓰지 않는다
        guard legs.contains(where: { $0.travelMode == .transit }) else {
            return "\(course.stops.count)곳 · 도보 약 \(duration) · 총 이동 \(distance)"
        }
        return "\(course.stops.count)곳 · 이동 약 \(duration) · 총 \(distance)"
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

    /// 장소 → 구간 경로 좌표 → 다음 장소 순서로 잇는다.
    /// 경로 좌표가 비었거나 값을 못 받은 구간은 장소끼리 직선이다
    var routeCoordinates: [Coordinate] {
        let legs = course?.legs ?? []
        return stops.enumerated().flatMap { index, stop -> [Coordinate] in
            guard legs.indices.contains(index), let leg = legs[index] else {
                return [stop.place.coordinate]
            }
            return [stop.place.coordinate] + leg.travelPath
        }
    }

    var routes: [MapRoute] {
        guard stops.count >= 2 else { return [] }
        return [MapRoute(id: "course-\(dateCourseID)", coordinates: routeCoordinates)]
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
                return CourseLeg(mode: .unavailable, duration: "", distance: "이동 정보를 불러오지 못했어요")
            }
            let duration = CourseResultText.duration(leg.travelMinutes)
            let distance = CourseResultText.legDistance(
                tenths: CourseResultText.tenthsOfKilometer(leg.travelDistanceMeters)
            )
            switch leg.travelMode {
            case .walking:
                return CourseLeg(mode: .walk, duration: "도보 \(duration)", distance: distance)
            case .transit:
                return CourseLeg(mode: .transit, duration: "대중교통 \(duration)", distance: distance)
            }
        }
    }

    /// 구간마다 앞 장소 → 다음 장소 카카오맵 길찾기 주소. 구간 수(`stops.count - 1`)만큼이다.
    /// 값을 못 받은 구간은 대중교통으로 연다. 대개 너무 멀어서 값이 비므로 도보 길찾기는 쓸모가 없다
    var legDirections: [CourseDirections?] {
        guard stops.count >= 2 else { return [] }
        let legs = course?.legs ?? []
        return (0 ..< stops.count - 1).map { index in
            let leg = legs.indices.contains(index) ? legs[index] : nil
            return CourseDirections(
                from: stops[index].place,
                to: stops[index + 1].place,
                mode: leg?.travelMode ?? .transit
            )
        }
    }
}

// MARK: - Directions

/// 구간 하나의 카카오맵 길찾기 주소. 앱을 먼저 열고, 앱이 안 받으면 웹을 연다
struct CourseDirections: Equatable {
    let appURL: URL
    let webURL: URL

    /// 주소를 만들지 못하면 nil
    init?(from origin: Place, to destination: Place, mode: CourseTravelMode) {
        let appMode: String
        let webMode: String
        switch mode {
        case .walking:
            appMode = "foot"
            webMode = "walk"
        case .transit:
            appMode = "publictransit"
            webMode = "traffic"
        }
        let start = origin.coordinate
        let end = destination.coordinate
        let app = "kakaomap://route"
            + "?sp=\(start.latitude),\(start.longitude)"
            + "&ep=\(end.latitude),\(end.longitude)"
            + "&by=\(appMode)"
        let web = "https://map.kakao.com/link/by/\(webMode)/"
            + "\(Self.webPoint(origin))/\(Self.webPoint(destination))"
        guard let appURL = URL(string: app), let webURL = URL(string: web) else { return nil }
        self.appURL = appURL
        self.webURL = webURL
    }

    /// `이름,위도,경도`. 쉼표·슬래시는 웹 주소의 구분자라 이름에서 공백으로 바꾼다
    private static func webPoint(_ place: Place) -> String {
        let name = place.name
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "/", with: " ")
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        return "\(encoded),\(place.coordinate.latitude),\(place.coordinate.longitude)"
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

    /// 0.1km 단위로 반올림한 거리. 행과 요약이 이 값 하나를 써서 요약이 행의 합과 같다
    static func tenthsOfKilometer(_ meters: Int) -> Int {
        Int((Double(meters) / 100).rounded())
    }

    static func summaryDistance(tenths: Int) -> String {
        "\(kilometers(tenths: tenths))km"
    }

    static func legDistance(tenths: Int) -> String {
        "\(kilometers(tenths: tenths)) km"
    }

    private static func kilometers(tenths: Int) -> String {
        "\(tenths / 10).\(tenths % 10)"
    }

    static func address(of place: Place) -> String {
        place.roadAddress ?? place.address
    }
}

// MARK: - 내 위치

private extension CourseResultFeature {
    func updateUserLocation(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .mapAppeared:
            // 다시 들어오면 새로 잡힌 좌표가 올 때까지 점을 안 보인다
            state.userLocation = nil
            return .run { [locationClient] send in
                for await coordinate in locationClient.coordinateUpdates() {
                    await send(.userLocationChanged(coordinate))
                }
            }
            .cancellable(id: CancelID.userLocation, cancelInFlight: true)

        case let .userLocationChanged(coordinate):
            state.userLocation = coordinate
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }
}
