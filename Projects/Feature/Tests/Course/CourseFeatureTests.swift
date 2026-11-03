import ComposableArchitecture
import CoreKakaoMap
import Domain
@testable import Feature
import SharedDesignSystem
import SharedUtils
import XCTest

@MainActor
final class CourseFeatureTests: XCTestCase {

    func test_State_tomorrow와_draftDate는_now의_다음날이다() {
        let calendar = Calendar.current
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 23, hour: 22, minute: 3)
        ) ?? Date.distantPast
        let state = CourseFeature.State(now: now)
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
        let expected = seoul.dateComponents(
            [.year, .month, .day],
            from: seoul.date(byAdding: .day, value: 1, to: now) ?? now
        )
        let today = calendar.dateComponents([.year, .month, .day], from: now)

        XCTAssertEqual(state.tomorrow, expected)
        XCTAssertEqual(state.draftDate, expected)
        XCTAssertEqual(state.draftTime.hour, 22)
        XCTAssertEqual(state.draftTime.minute, 3)
        XCTAssertNotEqual(state.tomorrow, today)
    }

    func test_날짜없이_다음_에러표시() async {
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nextTapped) {
            $0.showsDateError = true
        }
    }

    func test_다음을_누르면_코스를_만들고_ID를_들고_넘어간다() async {
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.courseClient.createCourse = { title, date, time in
                XCTAssertEqual(title, "30.08.05 데이트")
                XCTAssertEqual(date.day, 5)
                XCTAssertNil(time)
                return DateCourse(
                    id: "42",
                    title: title,
                    scheduledDate: Date(timeIntervalSince1970: 0),
                    scheduledTime: nil,
                    status: .draft,
                    version: 0,
                    stops: [],
                    legs: []
                )
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.dateFieldTapped)
        await store.send(.wheelDraftChanged(DateComponents(year: 2030, month: 8, day: 5)))
        await store.send(.wheelConfirmed)
        await store.send(.nextTapped) {
            $0.isCreatingCourse = true
        }
        await store.receive(\.courseCreated) {
            $0.isCreatingCourse = false
            $0.dateCourseID = "42"
            $0.version = 0
        }
        await store.receive(.delegate(.placePickRequested(dateCourseID: "42")))
    }

    func test_시간을_안_고르면_저장에_시간을_안_보낸다() async {
        let received = LockIsolated<DateComponents??>(nil)
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.courseClient.createCourse = { _, _, time in
                received.setValue(time)
                return DateCourse(
                    id: "1",
                    title: "t",
                    scheduledDate: Date(timeIntervalSince1970: 0),
                    scheduledTime: nil,
                    status: .draft,
                    version: 0,
                    stops: [],
                    legs: []
                )
            }
        }
        store.exhaustivity = .off

        await store.send(.dateFieldTapped)
        await store.send(.wheelConfirmed)
        await store.send(.nextTapped)
        await store.receive(\.courseCreated)
        await store.receive(.delegate(.placePickRequested(dateCourseID: "1")))

        XCTAssertEqual(received.value, .some(.none))
    }

    func test_코스_만들기가_실패하면_화면에_남고_토스트를_띄운다() async {
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.courseClient.createCourse = { _, _, _ in throw CourseError.network }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.dateFieldTapped)
        await store.send(.wheelDraftChanged(DateComponents(year: 2030, month: 8, day: 5)))
        await store.send(.wheelConfirmed)
        await store.send(.nextTapped) {
            $0.isCreatingCourse = true
        }
        await store.receive(\.courseCreated) {
            $0.isCreatingCourse = false
            $0.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
        }
        XCTAssertNil(store.state.dateCourseID)
    }

    func test_코스_만들기가_인증만료면_상위로_올린다() async {
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.courseClient.createCourse = { _, _, _ in throw CourseError.unauthorized }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.dateFieldTapped)
        await store.send(.wheelDraftChanged(DateComponents(year: 2030, month: 8, day: 5)))
        await store.send(.wheelConfirmed)
        await store.send(.nextTapped) {
            $0.isCreatingCourse = true
        }
        await store.receive(\.courseCreated) {
            $0.isCreatingCourse = false
        }
        await store.receive(.delegate(.sessionExpired))
        XCTAssertNil(store.state.toast)
        XCTAssertNil(store.state.dateCourseID)
    }

    func test_시트밖탭_임시값버림() async {
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.timeFieldTapped) {
            $0.activeWheel = .time
            $0.isWheelPresented = true
        }
        await store.send(.wheelDraftChanged(DateComponents(hour: 15, minute: 30))) {
            $0.draftTime = DateComponents(hour: 15, minute: 30)
        }
        await store.send(.wheelDismissed) {
            $0.isWheelPresented = false
        }
        XCTAssertEqual(store.state.activeWheel, .time)
        await store.send(.wheelDismissFinished) {
            $0.activeWheel = nil
        }
        XCTAssertNil(store.state.time)
    }

    func test_이미_고른_시간이_있으면_휠을_열어도_그_값이다() async {
        let calendar = Calendar.current
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 23, hour: 22, minute: 3)
        ) ?? Date.distantPast
        var initial = CourseFeature.State(now: now)
        initial.time = DateComponents(hour: 15, minute: 30)
        let store = TestStore(initialState: initial) {
            CourseFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.timeFieldTapped) {
            $0.activeWheel = .time
            $0.isWheelPresented = true
            $0.draftTime = DateComponents(hour: 15, minute: 30)
        }
    }
}

@MainActor
final class CourseScheduleAnalyticsTests: XCTestCase {

    func test_날짜를_넣고_다음을_누르면_일정완료_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        var initial = CourseFeature.State()
        initial.date = DateComponents(year: 2030, month: 8, day: 5)
        initial.time = DateComponents(hour: 13, minute: 0)
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.createCourse = { _, _, _ in
                DateCourse(
                    id: "1",
                    title: "t",
                    scheduledDate: Date(timeIntervalSince1970: 0),
                    scheduledTime: nil,
                    status: .draft,
                    version: 0,
                    stops: [],
                    legs: []
                )
            }
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nextTapped)
        await store.receive(\.courseCreated)
        await store.receive(.delegate(.placePickRequested(dateCourseID: "1")))
        await store.finish()

        XCTAssertEqual(sent.value, [.courseScheduleCompleted])
    }

    func test_날짜없이_다음을_누르면_일정완료_이벤트를_안_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nextTapped) {
            $0.showsDateError = true
        }
        await store.finish()

        XCTAssertEqual(sent.value, [])
    }

    func test_시간없이_날짜만_있어도_일정완료_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        var initial = CourseFeature.State()
        initial.date = DateComponents(year: 2030, month: 8, day: 5)
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.createCourse = { _, _, _ in
                DateCourse(
                    id: "1",
                    title: "t",
                    scheduledDate: Date(timeIntervalSince1970: 0),
                    scheduledTime: nil,
                    status: .draft,
                    version: 0,
                    stops: [],
                    legs: []
                )
            }
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nextTapped)
        await store.receive(\.courseCreated)
        await store.receive(.delegate(.placePickRequested(dateCourseID: "1")))
        await store.finish()

        XCTAssertNil(store.state.time)
        XCTAssertEqual(sent.value, [.courseScheduleCompleted])
    }

    func test_날짜입력후_다음_장소화면() async {
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.courseClient.createCourse = { _, _, _ in
                DateCourse(
                    id: "1",
                    title: "t",
                    scheduledDate: Date(timeIntervalSince1970: 0),
                    scheduledTime: nil,
                    status: .draft,
                    version: 0,
                    stops: [],
                    legs: []
                )
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.dateFieldTapped) {
            $0.activeWheel = .date
            $0.isWheelPresented = true
        }
        await store.send(.wheelDraftChanged(DateComponents(year: 2030, month: 8, day: 5))) {
            $0.draftDate = DateComponents(year: 2030, month: 8, day: 5)
        }
        await store.send(.wheelConfirmed) {
            $0.date = DateComponents(year: 2030, month: 8, day: 5)
            $0.isWheelPresented = false
            $0.showsDateError = false
        }
        await store.send(.nextTapped)
        await store.receive(\.courseCreated)
        await store.receive(.delegate(.placePickRequested(dateCourseID: "1")))
    }

    func test_시간없이_다음_통과() async {
        var initial = CourseFeature.State()
        initial.date = DateComponents(year: 2030, month: 8, day: 5)
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.courseClient.createCourse = { _, _, _ in
                DateCourse(
                    id: "1",
                    title: "t",
                    scheduledDate: Date(timeIntervalSince1970: 0),
                    scheduledTime: nil,
                    status: .draft,
                    version: 0,
                    stops: [],
                    legs: []
                )
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nextTapped)
        await store.receive(\.courseCreated)
        await store.receive(.delegate(.placePickRequested(dateCourseID: "1")))
        XCTAssertNil(store.state.time)
    }
}

@MainActor
final class CoursePlacePickTests: XCTestCase {
    private let savedPlaces: [SavedPlace] = [
        .candidateFixture(id: "a", latitude: 37.31, longitude: 126.90),
        .candidateFixture(id: "b", latitude: 37.32, longitude: 126.91),
        .candidateFixture(id: "c", latitude: 37.33, longitude: 126.92),
    ]

    private func loadedStore() -> TestStoreOf<CourseFeature> {
        var initial = CourseFeature.State()
        initial.places = savedPlaces
        initial.loadState = .loaded
        let store = TestStore(initialState: initial) { CourseFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }

    func test_행선택_번호부여() async {
        let store = loadedStore()

        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = ["a"] }
        await store.send(.rowTapped("b")) { $0.selectedPlaceIDs = ["a", "b"] }
        await store.send(.rowTapped("c")) { $0.selectedPlaceIDs = ["a", "b", "c"] }

        XCTAssertEqual(store.state.badgeState(for: "a"), .number(1))
        XCTAssertEqual(store.state.badgeState(for: "b"), .number(2))
        XCTAssertEqual(store.state.badgeState(for: "c"), .number(3))
    }

    func test_가운데해제_뒤번호당김() async {
        let store = loadedStore()

        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = ["a"] }
        await store.send(.rowTapped("b")) { $0.selectedPlaceIDs = ["a", "b"] }
        await store.send(.rowTapped("c")) { $0.selectedPlaceIDs = ["a", "b", "c"] }
        await store.send(.rowTapped("b")) { $0.selectedPlaceIDs = ["a", "c"] }

        XCTAssertEqual(store.state.badgeState(for: "a"), .number(1))
        XCTAssertEqual(store.state.badgeState(for: "c"), .number(2))
        XCTAssertEqual(store.state.badgeState(for: "b"), .unselected)
    }

    func test_장소를_담을_때만_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        var initial = CourseFeature.State()
        initial.places = savedPlaces
        initial.loadState = .loaded
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = ["a"] }
        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = [] }
        await store.finish()

        XCTAssertEqual(sent.value, [.placeAddedToCourse])
    }

    func test_숫자핀으로_빼면_담기_이벤트를_안_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        var initial = CourseFeature.State()
        initial.places = savedPlaces
        initial.loadState = .loaded
        initial.selectedPlaceIDs = ["a"]
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.markerTapped("numbered:a")) { $0.selectedPlaceIDs = [] }
        await store.finish()

        XCTAssertEqual(sent.value, [])
    }

    func test_CTA문구_개수반영() async {
        let store = loadedStore()

        XCTAssertEqual(store.state.ctaTitle, "장소를 선택해주세요")
        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = ["a"] }
        XCTAssertEqual(store.state.ctaTitle, "1곳으로 코스짜기")
        await store.send(.rowTapped("b")) { $0.selectedPlaceIDs = ["a", "b"] }
        await store.send(.rowTapped("c")) { $0.selectedPlaceIDs = ["a", "b", "c"] }
        XCTAssertEqual(store.state.ctaTitle, "3곳으로 코스짜기")
    }

    func test_CTA활성_1곳부터() async {
        let store = loadedStore()

        XCTAssertFalse(store.state.isCTAEnabled)
        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = ["a"] }
        XCTAssertTrue(store.state.isCTAEnabled)
    }

    func test_고른장소_카테고리핀_위에_숫자핀겹침() async {
        let store = loadedStore()

        XCTAssertEqual(store.state.markers.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(
            store.state.markers.map(\.kind),
            [.category(.food), .category(.food), .category(.food)]
        )

        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = ["a"] }
        await store.send(.rowTapped("c")) { $0.selectedPlaceIDs = ["a", "c"] }

        XCTAssertEqual(
            store.state.markers.map(\.id),
            ["a", "b", "c", "numbered:a", "numbered:c"]
        )
        XCTAssertEqual(
            store.state.markers.map(\.kind),
            [.category(.food), .category(.food), .category(.food), .numbered(1), .numbered(2)]
        )
    }

    func test_고른장소_필터밖_숫자핀과_경로선남음() async {
        let places: [SavedPlace] = [
            .candidateFixture(id: "a", latitude: 37.31, longitude: 126.90, category: .food),
            .candidateFixture(id: "b", latitude: 37.32, longitude: 126.91, category: .cafe),
        ]
        var initial = CourseFeature.State()
        initial.places = places
        initial.loadState = .loaded
        let store = TestStore(initialState: initial) { CourseFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = ["a"] }
        await store.send(.rowTapped("b")) { $0.selectedPlaceIDs = ["a", "b"] }
        await store.send(.categoryTapped(.cafe)) { $0.selectedCategory = .cafe }

        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["b"])
        XCTAssertEqual(store.state.markers.map(\.id), ["b", "numbered:a", "numbered:b"])
        XCTAssertEqual(
            store.state.markers.map(\.kind),
            [.category(.cafe), .numbered(1), .numbered(2)]
        )
        XCTAssertEqual(
            store.state.routes,
            [MapRoute(id: "course-pick", coordinates: places.map(\.place.coordinate))]
        )
    }

    func test_코스짜기_delegate() async {
        var initial = CourseFeature.State()
        initial.places = savedPlaces
        initial.loadState = .loaded
        initial.date = DateComponents(year: 2030, month: 8, day: 5)
        initial.time = DateComponents(hour: 13, minute: 0)
        initial.selectedPlaceIDs = ["a", "b"]
        initial.dateCourseID = "42"
        initial.version = 0
        let saved = DateCourse(
            id: "42",
            title: "30.08.05 데이트",
            scheduledDate: Date(timeIntervalSince1970: 0),
            scheduledTime: nil,
            status: .confirmed,
            version: 1,
            stops: [],
            legs: []
        )
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.updateCourse = { _, _, _ in saved }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.buildTapped)
        await store.receive(\.courseSaved)
        await store.receive(.delegate(.buildRequested(saved)))
    }

    func test_장소를_안_고르면_코스짜기가_나가지_않는다() async {
        var initial = CourseFeature.State()
        initial.places = savedPlaces
        initial.loadState = .loaded
        initial.date = DateComponents(year: 2030, month: 8, day: 5)
        initial.dateCourseID = "42"
        initial.version = 0
        let store = TestStore(initialState: initial) { CourseFeature() }

        await store.send(.buildTapped)
    }
}

@MainActor
final class CoursePlacePickMapTests: XCTestCase {

    func test_가운데를_빼면_뒤_숫자핀이_당겨진다() async {
        let store = mapStore(selected: ["a", "b", "c"])

        await store.send(.rowTapped("b")) {
            $0.selectedPlaceIDs = ["a", "c"]
            $0.camera = focused(candidateCoordinate("b"))
        }

        let numbered = store.state.markers.filter { $0.id.hasPrefix("numbered:") }
        XCTAssertEqual(numbered.map(\.id), ["numbered:a", "numbered:c"])
        XCTAssertEqual(numbered.map(\.kind), [.numbered(1), .numbered(2)])
    }

    func test_고른_순서대로_경로선을_잇는다() {
        let state = mapState(selected: ["c", "a"])

        XCTAssertEqual(
            state.routes,
            [MapRoute(id: "course-pick", coordinates: [candidateCoordinate("c"), candidateCoordinate("a")])]
        )
    }

    func test_가운데를_빼면_경로선이_앞뒤를_바로_잇는다() async {
        let store = mapStore(selected: ["a", "b", "c"])

        await store.send(.rowTapped("b")) {
            $0.selectedPlaceIDs = ["a", "c"]
            $0.camera = focused(candidateCoordinate("b"))
        }

        XCTAssertEqual(
            store.state.routes,
            [MapRoute(id: "course-pick", coordinates: [candidateCoordinate("a"), candidateCoordinate("c")])]
        )
    }

    func test_점이_둘보다_적으면_경로선이_없다() {
        XCTAssertEqual(mapState().routes, [])
        XCTAssertEqual(mapState(selected: ["a"]).routes, [])
        XCTAssertEqual(mapState(mode: .pick(existing: [existingStops[0]])).routes, [])
    }

    func test_행을_눌러_고르면_카메라가_지금_줌으로_그_장소에_간다() async {
        let store = mapStore()

        await store.send(.rowTapped("b")) {
            $0.selectedPlaceIDs = ["b"]
            $0.camera = focused(candidateCoordinate("b"))
        }
        await store.finish()
    }

    func test_행을_눌러_빼도_카메라가_그_장소에_간다() async {
        let store = mapStore(selected: ["b"])

        await store.send(.rowTapped("b")) {
            $0.selectedPlaceIDs = []
            $0.camera = focused(candidateCoordinate("b"))
        }
    }

    func test_핀을_눌러_고르면_목록을_그_행까지_올리고_카메라는_그대로다() async {
        let store = mapStore()

        await store.send(.markerTapped("b")) {
            $0.selectedPlaceIDs = ["b"]
            $0.rowScrollRequest = CourseFeature.RowScrollRequest(placeID: "b", sequence: 1)
        }
        await store.finish()
    }

    func test_숫자핀을_눌러_빼도_목록을_그_행까지_올리고_카메라는_그대로다() async {
        let store = mapStore(selected: ["b"])

        await store.send(.markerTapped("numbered:b")) {
            $0.selectedPlaceIDs = []
            $0.rowScrollRequest = CourseFeature.RowScrollRequest(placeID: "b", sequence: 1)
        }
    }

    func test_같은_핀을_다시_눌러도_스크롤_요청이_새로_나간다() async {
        let store = mapStore()

        await store.send(.markerTapped("b")) {
            $0.selectedPlaceIDs = ["b"]
            $0.rowScrollRequest = CourseFeature.RowScrollRequest(placeID: "b", sequence: 1)
        }
        await store.send(.markerTapped("numbered:b")) {
            $0.selectedPlaceIDs = []
            $0.rowScrollRequest = CourseFeature.RowScrollRequest(placeID: "b", sequence: 2)
        }
        await store.send(.markerTapped("b")) {
            $0.selectedPlaceIDs = ["b"]
            $0.rowScrollRequest = CourseFeature.RowScrollRequest(placeID: "b", sequence: 3)
        }
        await store.finish()
    }

    func test_필터에_걸린_고른_장소의_숫자핀은_빼기만_한다() async {
        let store = mapStore(selected: ["a"], category: .cafe)

        await store.send(.markerTapped("numbered:a")) {
            $0.selectedPlaceIDs = []
        }
    }
}

@MainActor
final class CoursePlaceAddMapTests: XCTestCase {

    func test_장소_추가는_불러오기_전부터_기존_코스의_마지막_장소를_본다() {
        let state = CourseFeature.State(mode: .pick(existing: existingStops))

        XCTAssertEqual(
            state.camera,
            .focusing(existingStops[1].coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        )
    }

    func test_장소_추가는_기존_장소를_카테고리핀과_숫자핀_1부터_N으로_보인다() {
        let state = mapState(mode: .pick(existing: existingStops))

        XCTAssertEqual(
            state.markers.map(\.id),
            ["existing:p0", "existing-numbered:p0", "existing:p1", "existing-numbered:p1", "a", "b", "c"]
        )
        XCTAssertEqual(
            state.markers.map(\.kind),
            [
                .category(.cafe), .numbered(1), .category(.food), .numbered(2),
                .category(.food), .category(.cafe), .category(.tourism),
            ]
        )
    }

    func test_기존_장소_핀은_필터와_상관없이_보인다() {
        let state = mapState(mode: .pick(existing: existingStops), category: .tourism)

        XCTAssertEqual(
            state.markers.map(\.id),
            ["existing:p0", "existing-numbered:p0", "existing:p1", "existing-numbered:p1", "c"]
        )
    }

    func test_장소_추가에서_새로_고른_장소는_N_다음_번호부터_센다() {
        let state = mapState(mode: .pick(existing: existingStops), selected: ["c", "a"])

        XCTAssertEqual(state.badgeState(for: "c"), .number(3))
        XCTAssertEqual(state.badgeState(for: "a"), .number(4))
        let numbered = state.markers.filter { $0.id.hasPrefix("numbered:") }
        XCTAssertEqual(numbered.map(\.id), ["numbered:c", "numbered:a"])
        XCTAssertEqual(numbered.map(\.kind), [.numbered(3), .numbered(4)])
    }

    func test_장소_추가의_경로선은_기존_장소_다음에_새로_고른_장소를_잇는다() {
        let state = mapState(mode: .pick(existing: existingStops), selected: ["c", "a"])

        XCTAssertEqual(
            state.routes,
            [
                MapRoute(
                    id: "course-pick",
                    coordinates: existingStops.map(\.coordinate)
                        + [candidateCoordinate("c"), candidateCoordinate("a")]
                ),
            ]
        )
    }

    func test_저장한_장소이기도_한_기존_장소는_핀이_한_벌만_선다() {
        let alsoSaved = ExistingCoursePlace(
            id: "a",
            category: .food,
            coordinate: candidateCoordinate("a")
        )
        let state = mapState(mode: .pick(existing: [alsoSaved]))

        XCTAssertEqual(state.filteredPlaces.map(\.id), ["b", "c"])
        XCTAssertEqual(state.markers.map(\.id), ["existing:a", "existing-numbered:a", "b", "c"])
    }

    func test_기존_장소_핀을_눌러도_아무_일도_없다() async {
        let store = mapStore(mode: .pick(existing: existingStops), selected: ["a"])

        await store.send(.markerTapped("existing-numbered:p0"))
        await store.send(.markerTapped("existing:p1"))
        await store.finish()
    }
}

@MainActor
final class CoursePickModeTests: XCTestCase {

    func test_고르기_모드는_저장하지_않고_고른_것을_올린다() async {
        let places = pickModeCandidates
        let store = TestStore(
            initialState: CourseFeature.State(mode: .pick(existing: [existing101]))
        ) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.coursePlaces = { places }
            $0.coupleClient.current = { .notConnected }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.coursePlacesResponse)
        await store.send(.rowTapped("102"))
        await store.send(.buildTapped)

        await store.receive(.delegate(.placesPicked(places.filter { $0.id == "102" })))
    }

    func test_고르기_모드에서_버튼을_누르면_생성_이벤트를_안_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let places = pickModeCandidates
        let store = TestStore(
            initialState: CourseFeature.State(mode: .pick(existing: [existing101]))
        ) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.coursePlaces = { places }
            $0.coupleClient.current = { .notConnected }
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.coursePlacesResponse)
        await store.send(.rowTapped("102"))
        sent.setValue([])
        await store.send(.buildTapped)
        await store.receive(.delegate(.placesPicked(places.filter { $0.id == "102" })))
        await store.finish()

        XCTAssertEqual(sent.value, [])
    }

    func test_고르기_모드는_이미_담긴_장소를_안_보인다() async {
        let places = pickModeCandidates
        let store = TestStore(
            initialState: CourseFeature.State(mode: .pick(existing: [existing101]))
        ) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.coursePlaces = { places }
            $0.coupleClient.current = { .notConnected }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.coursePlacesResponse)

        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["102"])
    }
}

@MainActor
final class CourseLoadTests: XCTestCase {

    func test_onAppear_저장장소_상태반영() async {
        let places: [SavedPlace] = [.candidateFixture(id: "a", latitude: 37.31, longitude: 126.90)]
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.coursePlaces = { places }
            $0.coupleClient.current = { .notConnected }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.coursePlacesResponse) {
            $0.places = places
            $0.loadState = .loaded
        }
    }

    func test_로드실패_재시도() async {
        let shouldFail = LockIsolated(true)
        let places: [SavedPlace] = [.candidateFixture(id: "a", latitude: 37.31, longitude: 126.90)]
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.coursePlaces = {
                if shouldFail.value { throw CourseError.network }
                return places
            }
            $0.coupleClient.current = { .notConnected }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.coursePlacesResponse) {
            $0.loadState = .failed
        }

        shouldFail.withValue { $0 = false }
        await store.send(.retryTapped) {
            $0.loadState = .loading
        }
        await store.receive(\.coursePlacesResponse) {
            $0.places = places
            $0.loadState = .loaded
        }
    }

    func test_커플닉네임_제목에반영() async {
        let status = CoupleStatus.connected(
            me: CoupleMember(nickname: "나", iconID: 0),
            partner: CoupleMember(nickname: "당근맛감자채", iconID: 1),
            daysTogether: 100
        )
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.coursePlaces = { [] }
            $0.coupleClient.current = { status }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.coupleResponse) {
            $0.partnerNickname = "당근맛감자채"
            $0.isCoupleConnected = true
        }
    }

    func test_미연결이면_저장자필터_되돌림() async {
        var initial = CourseFeature.State()
        initial.selectedOwnership = .mine
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.coursePlaces = { [] }
            $0.coupleClient.current = { .notConnected }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.coupleResponse) {
            $0.isCoupleConnected = false
            $0.selectedOwnership = .together
        }
    }
}

@MainActor
final class CourseFilterTests: XCTestCase {

    func test_필터변경_목록반영() async {
        let places: [SavedPlace] = [
            .candidateFixture(id: "a", latitude: 37.31, longitude: 126.90, category: .food),
            .candidateFixture(id: "b", latitude: 37.32, longitude: 126.91, category: .cafe),
        ]
        var initial = CourseFeature.State()
        initial.places = places
        initial.loadState = .loaded
        let store = TestStore(initialState: initial) { CourseFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["a", "b"])

        await store.send(.categoryTapped(.cafe)) { $0.selectedCategory = .cafe }
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["b"])

        await store.send(.categoryTapped(.cafe)) { $0.selectedCategory = nil }
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["a", "b"])
    }

    func test_저장자필터_카테고리와_겹친다() async {
        let places: [SavedPlace] = [
            .candidateFixture(id: "a", latitude: 37.31, longitude: 126.90, category: .food, ownership: .mine),
            .candidateFixture(id: "b", latitude: 37.32, longitude: 126.91, category: .cafe, ownership: .partner),
            .candidateFixture(id: "c", latitude: 37.33, longitude: 126.92, category: .food, ownership: .together),
        ]
        var initial = CourseFeature.State()
        initial.places = places
        initial.loadState = .loaded
        let store = TestStore(initialState: initial) { CourseFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["a", "b", "c"])

        await store.send(.ownershipSelected(.mine)) { $0.selectedOwnership = .mine }
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["a", "c"])

        await store.send(.ownershipSelected(.partner)) { $0.selectedOwnership = .partner }
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["b", "c"])

        await store.send(.categoryTapped(.food)) { $0.selectedCategory = .food }
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["c"])
    }
}

// MARK: - Fixture

private let pickModeCandidates: [SavedPlace] = [
    .candidateFixture(id: "101", latitude: 37.31, longitude: 126.90),
    .candidateFixture(id: "102", latitude: 37.32, longitude: 126.91),
]

/// 저장한 장소 101 과 같은 장소가 기존 코스에 담겨 있다
private let existing101 = ExistingCoursePlace(
    id: "101",
    category: .food,
    coordinate: Coordinate(latitude: 37.31, longitude: 126.90)
)

/// 장소 추가로 들어올 때의 기존 코스 장소. 후보 a·b·c 에 없는 id 다
private let existingStops: [ExistingCoursePlace] = [
    ExistingCoursePlace(id: "p0", category: .cafe, coordinate: Coordinate(latitude: 37.40, longitude: 127.00)),
    ExistingCoursePlace(id: "p1", category: .food, coordinate: Coordinate(latitude: 37.41, longitude: 127.01)),
]

/// 사용자가 줌을 바꿔 둔 카메라. 탭해도 줌이 그대로인지 보려고 기본 줌(14)과 다르게 둔다
private let pannedCamera = MapCamera(
    center: Coordinate(latitude: 37.5, longitude: 127.0),
    zoomLevel: 17
)

/// 후보 a·b·c 를 받아 둔 장소 선택 화면
private func mapState(
    mode: CourseFeature.Mode = .create,
    selected: [String] = [],
    category: PlaceCategory? = nil
) -> CourseFeature.State {
    var state = CourseFeature.State(mode: mode)
    state.places = PlaceFixtures.coursePlaceCandidates
    state.loadState = .loaded
    state.selectedPlaceIDs = selected
    state.selectedCategory = category
    state.camera = pannedCamera
    return state
}

@MainActor
private func mapStore(
    mode: CourseFeature.Mode = .create,
    selected: [String] = [],
    category: PlaceCategory? = nil
) -> TestStoreOf<CourseFeature> {
    TestStore(initialState: mapState(mode: mode, selected: selected, category: category)) {
        CourseFeature()
    }
}

/// 지금 줌(17)을 그대로 둔 채 그 좌표로 간 카메라
private func focused(_ coordinate: Coordinate) -> MapCamera {
    .focusing(coordinate, zoomLevel: pannedCamera.zoomLevel)
}

private func candidateCoordinate(_ id: String) -> Coordinate {
    PlaceFixtures.coursePlaceCandidates.first { $0.id == id }?.place.coordinate
        ?? Coordinate(latitude: 0, longitude: 0)
}

@MainActor
final class CoursePlacePickCameraTests: XCTestCase {

    func test_장소_목록을_받으면_첫_행으로_간다() async {
        let candidates = PlaceFixtures.coursePlaceCandidates
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        }

        await store.send(.coursePlacesResponse(.success(candidates))) {
            $0.places = candidates
            $0.loadState = .loaded
            $0.camera = .focusing(candidates[0].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
    }

    func test_장소가_없으면_서울_시청으로_간다() async {
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        }

        await store.send(.coursePlacesResponse(.success([]))) {
            $0.places = []
            $0.loadState = .loaded
            $0.camera = .seoulCityHall
        }
    }

    func test_장소_추가로_들어오면_기존_코스의_마지막_장소로_간다() async {
        let candidates = PlaceFixtures.coursePlaceCandidates
        let store = TestStore(initialState: CourseFeature.State(mode: .pick(existing: existingStops))) {
            CourseFeature()
        }

        await store.send(.coursePlacesResponse(.success(candidates))) {
            $0.places = candidates
            $0.loadState = .loaded
            $0.camera = .focusing(existingStops[1].coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
    }

    func test_검색_중에_목록을_다시_받아도_검색_결과가_아니라_받아_둔_목록의_첫_행으로_간다() async {
        let candidates = PlaceFixtures.coursePlaceCandidates
        let store = TestStore(initialState: searchedState(isFieldOpen: false)) {
            CourseFeature()
        }

        await store.send(.coursePlacesResponse(.success(candidates))) {
            $0.camera = .focusing(candidates[0].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
    }

    func test_장소_추가에_기존_장소가_없으면_첫_행으로_간다() async {
        let candidates = PlaceFixtures.coursePlaceCandidates
        let store = TestStore(initialState: CourseFeature.State(mode: .pick(existing: []))) {
            CourseFeature()
        }

        await store.send(.coursePlacesResponse(.success(candidates))) {
            $0.places = candidates
            $0.loadState = .loaded
            $0.camera = .focusing(candidates[0].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
    }
}

@MainActor
final class CourseSaveTests: XCTestCase {
    private let savedPlaces: [SavedPlace] = [
        .candidateFixture(id: "a", latitude: 37.31, longitude: 126.90),
        .candidateFixture(id: "b", latitude: 37.32, longitude: 126.91),
    ]

    private var confirmedCourse: DateCourse {
        DateCourse(
            id: "42",
            title: "30.08.05 데이트",
            scheduledDate: Date(timeIntervalSince1970: 0),
            scheduledTime: nil,
            status: .confirmed,
            version: 1,
            stops: [],
            legs: []
        )
    }

    private func loadedPlacePickState() -> CourseFeature.State {
        var initial = CourseFeature.State()
        initial.places = savedPlaces
        initial.loadState = .loaded
        initial.date = DateComponents(year: 2030, month: 8, day: 5)
        initial.time = DateComponents(hour: 13, minute: 0)
        initial.selectedPlaceIDs = ["a", "b"]
        initial.dateCourseID = "42"
        initial.version = 0
        return initial
    }

    private func placePickStore() -> TestStoreOf<CourseFeature> {
        let store = TestStore(initialState: loadedPlacePickState()) { CourseFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }

    func test_코스짜기를_누르면_저장하고_결과로_넘긴다() async {
        let saved = confirmedCourse
        let store = placePickStore()
        store.dependencies.courseClient.updateCourse = { id, content, version in
            XCTAssertEqual(id, "42")
            XCTAssertEqual(content.title, "30.08.05 데이트")
            XCTAssertEqual(content.date, seoulMidnight(year: 2030, month: 8, day: 5))
            XCTAssertEqual(content.time, DateComponents(hour: 13, minute: 0))
            XCTAssertEqual(content.placeIDs, ["a", "b"])
            XCTAssertEqual(version, 0)
            return saved
        }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        await store.receive(\.courseSaved.success) {
            $0.isSavingCourse = false
            $0.version = saved.version
        }
        await store.receive(.delegate(.buildRequested(saved)))
    }

    func test_코스짜기를_누르면_생성_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let saved = confirmedCourse
        let store = placePickStore()
        store.dependencies.analyticsClient.track = { event in
            sent.withValue { $0.append(event) }
        }
        store.dependencies.courseClient.updateCourse = { _, _, _ in saved }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        await store.receive(\.courseSaved.success) {
            $0.isSavingCourse = false
            $0.version = saved.version
        }
        await store.receive(.delegate(.buildRequested(saved)))
        await store.finish()
        XCTAssertEqual(sent.value, [.courseCreated])
    }

    func test_코스_저장_성공은_생성_이벤트를_안_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let saved = confirmedCourse
        let store = placePickStore()
        store.dependencies.analyticsClient.track = { event in
            sent.withValue { $0.append(event) }
        }
        store.dependencies.courseClient.updateCourse = { _, _, _ in saved }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        sent.setValue([])
        await store.receive(\.courseSaved.success) {
            $0.isSavingCourse = false
            $0.version = saved.version
        }
        await store.receive(.delegate(.buildRequested(saved)))
        await store.finish()
        XCTAssertEqual(sent.value, [])
    }

    func test_시간없이_코스짜기를_누르면_저장에_시간을_안_보낸다() async {
        let saved = confirmedCourse
        var initial = loadedPlacePickState()
        initial.time = nil
        let store = TestStore(initialState: initial) { CourseFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)
        store.dependencies.courseClient.updateCourse = { _, content, _ in
            XCTAssertEqual(content.date, seoulMidnight(year: 2030, month: 8, day: 5))
            XCTAssertNil(content.time)
            return saved
        }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        await store.receive(\.courseSaved.success)
        await store.receive(.delegate(.buildRequested(saved)))
    }

    func test_저장이_409면_다시_읽고_알린다() async {
        let latest = DateCourse(
            id: "42",
            title: "30.08.05 데이트",
            scheduledDate: Date(timeIntervalSince1970: 0),
            scheduledTime: nil,
            status: .confirmed,
            version: 2,
            stops: [],
            legs: []
        )
        let store = placePickStore()
        store.dependencies.courseClient.updateCourse = { _, _, _ in throw CourseError.conflict }
        store.dependencies.courseClient.course = { _ in latest }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        await store.receive(\.courseSaved.failure)
        await store.receive(\.conflictReloaded.success) {
            $0.isSavingCourse = false
            $0.version = latest.version
            $0.conflictAlertMessage = "상대방이 코스를 먼저 바꿨어요. 다시 확인해주세요"
        }
    }

    func test_409인데_다시_읽기도_실패하면_토스트가_뜬다() async {
        let store = placePickStore()
        store.dependencies.courseClient.updateCourse = { _, _, _ in throw CourseError.conflict }
        store.dependencies.courseClient.course = { _ in throw CourseError.network }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        await store.receive(\.courseSaved.failure)
        await store.receive(\.conflictReloaded.failure) {
            $0.isSavingCourse = false
            $0.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
        }
    }

    func test_저장_중에는_버튼이_잠긴다() async {
        var initial = loadedPlacePickState()
        initial.isSavingCourse = true
        XCTAssertFalse(initial.isCTAEnabled)
    }

    func test_저장이_실패하면_토스트를_띄운다() async {
        let store = placePickStore()
        store.dependencies.courseClient.updateCourse = { _, _, _ in throw CourseError.network }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        await store.receive(\.courseSaved.failure) {
            $0.isSavingCourse = false
            $0.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
        }
    }

    func test_저장이_인증만료면_상위로_올린다() async {
        let store = placePickStore()
        store.dependencies.courseClient.updateCourse = { _, _, _ in throw CourseError.unauthorized }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        await store.receive(\.courseSaved.failure) {
            $0.isSavingCourse = false
        }
        await store.receive(.delegate(.sessionExpired))
        XCTAssertNil(store.state.toast)
    }

    func test_저장_중_뒤로가면_저장을_끊는다() async {
        let store = placePickStore()
        store.dependencies.courseClient.updateCourse = { _, _, _ in
            try await Task.never()
        }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        await store.send(.backTapped) {
            $0.isSavingCourse = false
        }
        await store.receive(.delegate(.dismissed))
    }

    func test_재조회_중_뒤로가면_재조회를_끊고_알림을_비운다() async {
        let store = placePickStore()
        store.dependencies.courseClient.updateCourse = { _, _, _ in throw CourseError.conflict }
        store.dependencies.courseClient.course = { _ in
            try await Task.never()
        }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        await store.receive(\.courseSaved.failure)
        await store.send(.backTapped) {
            $0.isSavingCourse = false
            $0.conflictAlertMessage = nil
        }
        await store.receive(.delegate(.dismissed))
    }
}

private func seoulMidnight(year: Int, month: Int, day: Int) -> Date {
    var midnight = DateComponents(year: year, month: month, day: day)
    midnight.hour = 0
    midnight.minute = 0
    midnight.second = 0
    midnight.timeZone = TimeZone(identifier: "Asia/Seoul")
    return Calendar(identifier: .gregorian).date(from: midnight) ?? Date.distantPast
}

// MARK: - 내 위치 점

@MainActor
final class CoursePlacePickUserLocationTests: XCTestCase {

    func test_장소_고르기_지도가_보이면_흐름의_좌표로_점을_그린다() async {
        let here = Coordinate(latitude: 37.5665, longitude: 126.9780)
        let (stream, continuation) = AsyncStream<Coordinate?>.makeStream()
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.locationClient.coordinateUpdates = { stream }
        }

        await store.send(.mapAppeared)
        continuation.yield(here)
        await store.receive(\.userLocationChanged) {
            $0.userLocation = here
        }

        continuation.finish()
        await store.finish()
    }

    func test_장소_고르기_지도가_사라지면_흐름을_끊는다() async {
        let here = Coordinate(latitude: 37.5665, longitude: 126.9780)
        let (stream, continuation) = AsyncStream<Coordinate?>.makeStream()
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.locationClient.coordinateUpdates = { stream }
        }

        let task = await store.send(.mapAppeared)
        continuation.yield(here)
        await store.receive(\.userLocationChanged) {
            $0.userLocation = here
        }

        // 흐름은 아직 열려 있다. 뷰의 task 가 취소되어 효과가 끊겨야 이 테스트가 끝난다
        await task.cancel()
    }

    func test_장소_고르기_다시_들어오면_새_좌표가_올_때까지_점을_지운다() async {
        let here = Coordinate(latitude: 37.5665, longitude: 126.9780)
        let (stream, continuation) = AsyncStream<Coordinate?>.makeStream()
        var state = CourseFeature.State()
        state.userLocation = here
        let store = TestStore(initialState: state) {
            CourseFeature()
        } withDependencies: {
            $0.locationClient.coordinateUpdates = { stream }
        }

        let task = await store.send(.mapAppeared) {
            $0.userLocation = nil
        }

        continuation.finish()
        await task.finish()
    }
}

// MARK: - Search Fixture

/// 받아 둔 목록(a·b·c)에 없는 장소. 목록을 받은 뒤 저장해 검색에만 나온다. 내가 저장한 음식점이다
private let searchOnlyD = SavedPlace.candidateFixture(
    id: "d",
    latitude: 37.34,
    longitude: 126.93,
    category: .food,
    ownership: .mine
)

/// 상대가 저장한 음식점
private let searchOnlyE = SavedPlace.candidateFixture(
    id: "e",
    latitude: 37.35,
    longitude: 126.94,
    category: .food,
    ownership: .partner
)

/// 둘이 저장한 카페
private let searchOnlyF = SavedPlace.candidateFixture(
    id: "f",
    latitude: 37.36,
    longitude: 126.95,
    category: .cafe
)

/// a·b·c 를 받아 둔 화면에서 검색어를 넣고 결과를 받은 상태
private func searchedState(
    query: String = "칼국",
    results: [SavedPlace] = [searchOnlyD],
    isFieldOpen: Bool = true,
    selected: [String] = [],
    mode: CourseFeature.Mode = .create
) -> CourseFeature.State {
    var state = mapState(mode: mode, selected: selected)
    state.search.isFieldOpen = isFieldOpen
    state.search.query = query
    state.search.results = results
    state.search.foundPlaces = results
    state.search.loadState = .loaded
    return state
}

/// 받은 검색 요청을 "검색어#페이지" 로 적는다
private func recordingSearch(
    _ requested: LockIsolated<[String]>,
    pages: [Int: Page<SavedPlace>]
) -> @Sendable (String?, Int) async throws -> Page<SavedPlace> {
    { query, page in
        requested.withValue { $0.append("\(query ?? "nil")#\(page)") }
        return pages[page] ?? Page(items: [], hasNext: false)
    }
}

/// 받은 요청을 적고 `delay` 만큼 붙잡은 뒤 그 검색어의 결과를 준다. 응답 전에 끊기는지 볼 때 쓴다
private func slowSearch(
    _ requested: LockIsolated<[String]>,
    clock: TestClock<Duration>,
    delay: Duration = .seconds(1),
    results: [String: [SavedPlace]]
) -> @Sendable (String?, Int) async throws -> Page<SavedPlace> {
    { query, page in
        requested.withValue { $0.append("\(query ?? "nil")#\(page)") }
        try await clock.sleep(for: delay)
        return Page(items: results[query ?? ""] ?? [], hasNext: false)
    }
}

/// 요청이 `count` 개 나갈 때까지 실제 시간으로 최대 1초 기다린다.
/// 이펙트가 도는 스레드는 TestClock 이 앞당기지 못해, 바쁜 CI 에서도 버티게 10ms 씩 다시 본다
private func waitForRequests(_ requested: LockIsolated<[String]>, count: Int) async {
    let deadline = ContinuousClock.now.advanced(by: .seconds(1))
    while requested.value.count < count && ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertEqual(requested.value.count, count, "검색 요청 \(count)개가 1초 안에 나가야 한다")
}

// MARK: - Search Input

@MainActor
final class CoursePlaceSearchInputTests: XCTestCase {

    func test_목록이_뜨기_전에는_검색칩을_눌러도_검색창이_안_열린다() async {
        var loading = mapState()
        loading.loadState = .loading
        var failed = mapState()
        failed.loadState = .failed
        XCTAssertFalse(loading.isSearchAvailable)
        XCTAssertFalse(failed.isSearchAvailable)
        XCTAssertTrue(mapState().isSearchAvailable)

        let store = TestStore(initialState: loading) { CourseFeature() }
        await store.send(.searchChipTapped)

        let failedStore = TestStore(initialState: failed) { CourseFeature() }
        await failedStore.send(.searchChipTapped)
    }

    func test_목록이_뜬_뒤_검색칩을_누르면_검색창이_열린다() async {
        let store = TestStore(initialState: mapState()) { CourseFeature() }

        await store.send(.searchChipTapped) {
            $0.search.isFieldOpen = true
        }
    }

    func test_검색어를_치고_300ms_멈추면_공백을_뺀_검색어만_보내_찾는다() async {
        let clock = TestClock()
        let requested = LockIsolated<[String]>([])
        var initial = mapState()
        initial.search.isFieldOpen = true
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.courseClient.searchCoursePlaces = recordingSearch(
                requested,
                pages: [0: Page(items: [searchOnlyD], hasNext: false)]
            )
        }

        await store.send(.searchQueryChanged("칼국 ")) {
            $0.search.query = "칼국 "
        }
        await clock.advance(by: .milliseconds(299))
        XCTAssertEqual(requested.value, [])

        await clock.advance(by: .milliseconds(1))
        await store.receive(\.searchDebounced) {
            $0.search.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.search.results = [searchOnlyD]
            $0.search.foundPlaces = [searchOnlyD]
            $0.search.loadState = .loaded
        }
        XCTAssertEqual(requested.value, ["칼국#0"])
        // 지도는 걸러진 결과만 그리고, 화면 위치는 그대로다
        XCTAssertEqual(store.state.markers.map(\.id), ["d"])
        XCTAssertEqual(store.state.camera, pannedCamera)
    }

    func test_검색어를_바꾸면_기다리던_검색을_끊고_마지막_검색어로만_찾는다() async {
        let clock = TestClock()
        let requested = LockIsolated<[String]>([])
        var initial = mapState()
        initial.search.isFieldOpen = true
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.courseClient.searchCoursePlaces = recordingSearch(
                requested,
                pages: [0: Page(items: [searchOnlyD], hasNext: false)]
            )
        }

        await store.send(.searchQueryChanged("칼")) {
            $0.search.query = "칼"
        }
        await clock.advance(by: .milliseconds(200))
        await store.send(.searchQueryChanged("칼국")) {
            $0.search.query = "칼국"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.searchDebounced) {
            $0.search.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.search.results = [searchOnlyD]
            $0.search.foundPlaces = [searchOnlyD]
            $0.search.loadState = .loaded
        }
        XCTAssertEqual(requested.value, ["칼국#0"])
    }

    func test_검색어를_지우면_서버를_부르지_않고_받아_둔_목록_전체로_돌아간다() async {
        let store = TestStore(initialState: searchedState()) { CourseFeature() }

        await store.send(.searchQueryChanged("  ")) {
            $0.search.query = "  "
            $0.search.results = []
            $0.search.loadState = .idle
        }
        XCTAssertFalse(store.state.isSearching)
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["a", "b", "c"])
    }

    func test_검색을_기다리는_중에_취소하면_서버를_부르지_않는다() async {
        let clock = TestClock()
        let requested = LockIsolated<[String]>([])
        var initial = mapState()
        initial.search.isFieldOpen = true
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.courseClient.searchCoursePlaces = recordingSearch(requested, pages: [:])
        }

        await store.send(.searchQueryChanged("칼국")) {
            $0.search.query = "칼국"
        }
        await store.send(.searchCancelTapped) {
            $0.search.isFieldOpen = false
            $0.search.query = ""
        }
        await clock.advance(by: .milliseconds(300))
        XCTAssertEqual(requested.value, [])
    }

    func test_검색어가_있는_채로_키보드가_내려가면_검색어_칩이_된다() async {
        let store = TestStore(initialState: searchedState(query: "칼국수")) { CourseFeature() }

        await store.send(.searchFieldDismissed) {
            $0.search.isFieldOpen = false
        }
        XCTAssertTrue(store.state.isSearching)
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["d"])
    }

    func test_빈_검색어로_키보드가_내려가면_검색칩으로_돌아간다() async {
        var initial = mapState()
        initial.search.isFieldOpen = true
        initial.search.query = " "
        let store = TestStore(initialState: initial) { CourseFeature() }

        await store.send(.searchFieldDismissed) {
            $0.search.isFieldOpen = false
            $0.search.query = ""
        }
    }

    func test_검색창이_닫힌_뒤_늦게_온_키보드_내려감은_무시한다() async {
        let store = TestStore(initialState: searchedState(isFieldOpen: false)) { CourseFeature() }

        await store.send(.searchFieldDismissed)
    }

    func test_취소를_누르면_검색을_풀고_받아_둔_목록_전체로_돌아간다() async {
        var initial = searchedState()
        initial.search.hasNext = true
        initial.search.page = 2
        let store = TestStore(initialState: initial) { CourseFeature() }

        await store.send(.searchCancelTapped) {
            $0.search.isFieldOpen = false
            $0.search.query = ""
            $0.search.results = []
            $0.search.loadState = .idle
            $0.search.page = 0
            $0.search.hasNext = false
        }
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["a", "b", "c"])
    }

    func test_검색어_칩의_X를_누르면_검색을_풀고_받아_둔_목록_전체로_돌아간다() async {
        let store = TestStore(initialState: searchedState(query: "칼국수", isFieldOpen: false)) {
            CourseFeature()
        }

        await store.send(.searchChipClearTapped) {
            $0.search.query = ""
            $0.search.results = []
            $0.search.loadState = .idle
        }
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["a", "b", "c"])
    }

    func test_검색어_칩을_누르면_검색어가_든_채로_검색창이_다시_열린다() async {
        let store = TestStore(initialState: searchedState(query: "칼국수", isFieldOpen: false)) {
            CourseFeature()
        }

        await store.send(.searchChipTapped) {
            $0.search.isFieldOpen = true
        }
        XCTAssertEqual(store.state.search.query, "칼국수")
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["d"])
    }
}

// MARK: - Search Request

/// 검색어가 바뀌는 사이 기다림 화면과, 돌던 요청을 끊는 것
@MainActor
final class CoursePlaceSearchRequestTests: XCTestCase {

    func test_검색어를_바꾸면_기다리는_동안_앞_검색어의_빈_결과_대신_가짜_행을_보인다() async {
        let clock = TestClock()
        // 카페만 보는데 음식점만 와서 다음 페이지를 이어 부르던 중이다
        var initial = searchedState(query: "칼국")
        initial.selectedCategory = .cafe
        initial.search.hasNext = true
        initial.search.isLoadingMore = true
        XCTAssertEqual(initial.listContent, .skeleton)
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.searchQueryChanged("칼국수")) {
            $0.search.query = "칼국수"
            $0.search.hasNext = false
            $0.search.isLoadingMore = false
            $0.search.loadState = .idle
        }
        XCTAssertEqual(store.state.listContent, .skeleton)
        await store.skipInFlightEffects()
    }

    func test_검색이_실패한_뒤_검색어를_바꾸면_기다리는_동안_가짜_행을_보인다() async {
        let clock = TestClock()
        var initial = searchedState(results: [])
        initial.search.loadState = .failed
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.searchQueryChanged("칼국수")) {
            $0.search.query = "칼국수"
            $0.search.loadState = .idle
        }
        XCTAssertEqual(store.state.listContent, .skeleton)
        await store.skipInFlightEffects()
    }

    func test_다듬은_검색어가_같으면_다시_찾지_않는다() async {
        let clock = TestClock()
        let requested = LockIsolated<[String]>([])
        var initial = searchedState(query: "칼국")
        initial.search.hasNext = true
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.courseClient.searchCoursePlaces = recordingSearch(requested, pages: [:])
        }

        await store.send(.searchQueryChanged("칼국 ")) {
            $0.search.query = "칼국 "
        }
        await store.send(.searchQueryChanged("칼국 "))
        await clock.advance(by: .milliseconds(300))
        XCTAssertEqual(requested.value, [])
        XCTAssertEqual(store.state.listContent, .list)
    }

    func test_검색_요청이_도는_중에_검색어를_바꾸면_옛_응답을_버린다() async {
        let clock = TestClock()
        let requested = LockIsolated<[String]>([])
        var initial = mapState()
        initial.search.isFieldOpen = true
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.continuousClock = clock
            // 새 검색어의 300ms 기다림보다 빨리 끝나는 요청이다. 새 요청이 옛 요청을 덮기 전에 옛 응답이 온다
            $0.courseClient.searchCoursePlaces = slowSearch(
                requested,
                clock: clock,
                delay: .milliseconds(100),
                results: ["칼국": [searchOnlyD], "칼국수": [searchOnlyE]]
            )
        }

        await store.send(.searchQueryChanged("칼국")) {
            $0.search.query = "칼국"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.searchDebounced) {
            $0.search.loadState = .loading
        }
        await waitForRequests(requested, count: 1)

        await store.send(.searchQueryChanged("칼국수")) {
            $0.search.query = "칼국수"
            $0.search.loadState = .idle
        }
        // 끊기지 않았다면 기다리는 사이 「칼국」 응답이 온다
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.searchDebounced) {
            $0.search.loadState = .loading
        }
        await clock.advance(by: .milliseconds(100))
        await store.receive(\.searchResponse.success) {
            $0.search.results = [searchOnlyE]
            $0.search.foundPlaces = [searchOnlyE]
            $0.search.loadState = .loaded
        }
        XCTAssertEqual(requested.value, ["칼국#0", "칼국수#0"])
    }

    func test_다음_페이지_요청이_도는_중에_검색어를_바꾸면_옛_응답을_버린다() async {
        let clock = TestClock()
        let requested = LockIsolated<[String]>([])
        var initial = searchedState()
        initial.search.hasNext = true
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.courseClient.searchCoursePlaces = slowSearch(
                requested,
                clock: clock,
                results: ["칼국": [searchOnlyF], "칼국수": [searchOnlyE]]
            )
        }

        await store.send(.searchReachedEnd) {
            $0.search.isLoadingMore = true
        }
        await waitForRequests(requested, count: 1)

        await store.send(.searchQueryChanged("칼국수")) {
            $0.search.query = "칼국수"
            $0.search.hasNext = false
            $0.search.isLoadingMore = false
            $0.search.loadState = .idle
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.searchDebounced) {
            $0.search.loadState = .loading
        }
        // 끊기지 않았다면 여기서 「칼국」 의 다음 페이지 응답이 먼저 온다
        await clock.advance(by: .seconds(1))
        await store.receive(\.searchResponse.success) {
            $0.search.results = [searchOnlyE]
            $0.search.foundPlaces = [searchOnlyD, searchOnlyE]
            $0.search.loadState = .loaded
        }
        XCTAssertEqual(requested.value, ["칼국#1", "칼국수#0"])
    }

    func test_검색_요청이_도는_중에_취소하면_옛_응답을_버린다() async {
        let clock = TestClock()
        let requested = LockIsolated<[String]>([])
        var initial = mapState()
        initial.search.isFieldOpen = true
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.courseClient.searchCoursePlaces = slowSearch(
                requested,
                clock: clock,
                results: ["칼국": [searchOnlyD]]
            )
        }

        await store.send(.searchQueryChanged("칼국")) {
            $0.search.query = "칼국"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.searchDebounced) {
            $0.search.loadState = .loading
        }
        await waitForRequests(requested, count: 1)

        await store.send(.searchCancelTapped) {
            $0.search.isFieldOpen = false
            $0.search.query = ""
            $0.search.loadState = .idle
        }
        // 끊기지 않았다면 여기서 「칼국」 응답이 온다
        await clock.advance(by: .seconds(1))
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["a", "b", "c"])
    }
}

// MARK: - Search Result

@MainActor
final class CoursePlaceSearchResultTests: XCTestCase {

    func test_검색_결과에도_카테고리와_저장자와_코스에_있는_장소_빼기가_함께_걸린다() {
        let takenA = ExistingCoursePlace(id: "a", category: .food, coordinate: candidateCoordinate("a"))
        let candidates = PlaceFixtures.coursePlaceCandidates
        var state = searchedState(
            query: "카",
            results: [candidates[0], candidates[1], searchOnlyD, searchOnlyE],
            mode: .pick(existing: [takenA])
        )
        XCTAssertEqual(state.filteredPlaces.map(\.id), ["b", "d", "e"])

        state.selectedOwnership = .mine
        state.selectedCategory = .food
        XCTAssertEqual(state.filteredPlaces.map(\.id), ["d"])
    }

    func test_앱이_걸러_한_페이지가_비면_다음_페이지를_이어_부른다() async {
        let requested = LockIsolated<[String]>([])
        var initial = searchedState(query: "카", results: [])
        initial.search.loadState = .idle
        initial.selectedCategory = .cafe
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.searchCoursePlaces = recordingSearch(
                requested,
                pages: [
                    0: Page(items: [searchOnlyD], hasNext: true),
                    1: Page(items: [searchOnlyF], hasNext: false),
                ]
            )
        }

        await store.send(.searchDebounced) {
            $0.search.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.search.results = [searchOnlyD]
            $0.search.foundPlaces = [searchOnlyD]
            $0.search.hasNext = true
            $0.search.loadState = .loaded
            // 카페만 보는데 음식점 한 곳만 와서 보일 행이 없다
            $0.search.isLoadingMore = true
        }
        await store.receive(\.searchMoreResponse.success) {
            $0.search.results = [searchOnlyD, searchOnlyF]
            $0.search.foundPlaces = [searchOnlyD, searchOnlyF]
            $0.search.page = 1
            $0.search.hasNext = false
            $0.search.isLoadingMore = false
        }
        XCTAssertEqual(requested.value, ["카#0", "카#1"])
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["f"])
    }

    func test_검색_결과_끝에_닿으면_다음_페이지를_붙인다() async {
        let requested = LockIsolated<[String]>([])
        var initial = searchedState()
        initial.search.hasNext = true
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.searchCoursePlaces = recordingSearch(
                requested,
                pages: [1: Page(items: [searchOnlyE], hasNext: false)]
            )
        }

        await store.send(.searchReachedEnd) {
            $0.search.isLoadingMore = true
        }
        await store.receive(\.searchMoreResponse.success) {
            $0.search.results = [searchOnlyD, searchOnlyE]
            $0.search.foundPlaces = [searchOnlyD, searchOnlyE]
            $0.search.page = 1
            $0.search.hasNext = false
            $0.search.isLoadingMore = false
        }
        XCTAssertEqual(requested.value, ["칼국#1"])
    }

    func test_다음_페이지가_없으면_끝에_닿아도_부르지_않는다() async {
        let store = TestStore(initialState: searchedState()) { CourseFeature() }

        await store.send(.searchReachedEnd)
    }

    func test_검색_중_필터를_바꿔_보일_행이_없어지면_다음_페이지를_부른다() async {
        var initial = searchedState()
        initial.search.hasNext = true
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.searchCoursePlaces = { _, page in
                XCTAssertEqual(page, 1)
                return Page(items: [searchOnlyF], hasNext: false)
            }
        }

        await store.send(.categoryTapped(.cafe)) {
            $0.selectedCategory = .cafe
            $0.search.isLoadingMore = true
        }
        await store.receive(\.searchMoreResponse.success) {
            $0.search.results = [searchOnlyD, searchOnlyF]
            $0.search.foundPlaces = [searchOnlyD, searchOnlyF]
            $0.search.page = 1
            $0.search.hasNext = false
            $0.search.isLoadingMore = false
        }
    }

    func test_검색이_실패하면_실패_상태가_되고_다시_치면_다시_찾는다() async {
        let clock = TestClock()
        let shouldFail = LockIsolated(true)
        let store = TestStore(initialState: searchedState()) {
            CourseFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.courseClient.searchCoursePlaces = { _, _ in
                if shouldFail.value { throw CourseError.network }
                return Page(items: [searchOnlyD], hasNext: false)
            }
        }

        await store.send(.searchDebounced) {
            $0.search.loadState = .loading
        }
        await store.receive(\.searchResponse.failure) {
            $0.search.results = []
            $0.search.loadState = .failed
        }
        XCTAssertEqual(store.state.listContent, .searchFailed)

        shouldFail.setValue(false)
        await store.send(.searchQueryChanged("칼국수")) {
            $0.search.query = "칼국수"
            $0.search.loadState = .idle
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.searchDebounced) {
            $0.search.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.search.results = [searchOnlyD]
            $0.search.loadState = .loaded
        }
    }

    func test_검색에서_세션이_만료되면_위로_올린다() async {
        let store = TestStore(initialState: searchedState()) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.searchCoursePlaces = { _, _ in throw CourseError.unauthorized }
        }

        await store.send(.searchDebounced) {
            $0.search.loadState = .loading
        }
        await store.receive(\.searchResponse.failure) {
            $0.search.results = []
            $0.search.loadState = .failed
        }
        await store.receive(\.delegate.sessionExpired)
    }

    func test_다음_페이지에서_세션이_만료돼도_위로_올린다() async {
        var initial = searchedState()
        initial.search.hasNext = true
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.searchCoursePlaces = { _, _ in throw CourseError.unauthorized }
        }

        await store.send(.searchReachedEnd) {
            $0.search.isLoadingMore = true
        }
        await store.receive(\.searchMoreResponse.failure) {
            $0.search.isLoadingMore = false
        }
        await store.receive(\.delegate.sessionExpired)
    }
}

// MARK: - Search List Content

@MainActor
final class CoursePlaceSearchListContentTests: XCTestCase {

    func test_검색_결과를_기다리는_동안_가짜_행을_보인다() {
        var state = searchedState(results: [])
        // 300ms 기다리는 중
        state.search.loadState = .idle
        XCTAssertEqual(state.listContent, .skeleton)

        state.search.loadState = .loading
        XCTAssertEqual(state.listContent, .skeleton)

        // 걸러져 비었지만 다음 페이지를 이어 부르는 중
        state.search.loadState = .loaded
        state.search.results = [searchOnlyD]
        state.selectedCategory = .cafe
        state.search.hasNext = true
        XCTAssertEqual(state.listContent, .skeleton)
    }

    func test_검색_결과가_없거나_실패하면_그에_맞는_화면을_보인다() {
        var state = searchedState(results: [])
        XCTAssertEqual(state.listContent, .noSearchResult)

        state.search.loadState = .failed
        XCTAssertEqual(state.listContent, .searchFailed)

        state.search.loadState = .loaded
        state.search.results = [searchOnlyD]
        XCTAssertEqual(state.listContent, .list)
    }

    func test_검색하지_않을_때는_목록_상태를_그대로_보인다() {
        var state = mapState()
        XCTAssertEqual(state.listContent, .list)

        state.selectedCategory = .accommodation
        XCTAssertEqual(state.listContent, .noMatch)

        state.places = []
        XCTAssertEqual(state.listContent, .noSavedPlace)

        state.loadState = .loading
        XCTAssertEqual(state.listContent, .skeleton)

        state.loadState = .failed
        XCTAssertEqual(state.listContent, .loadFailed)
    }
}

// MARK: - Search Selection

@MainActor
final class CoursePlaceSearchSelectionTests: XCTestCase {

    func test_입력_중에_행을_누르면_고르고_키보드가_내려가면_검색어_칩이_된다() async {
        let store = TestStore(initialState: searchedState()) { CourseFeature() }

        await store.send(.rowTapped("d")) {
            $0.selectedPlaceIDs = ["d"]
            $0.camera = focused(searchOnlyD.place.coordinate)
        }
        await store.send(.searchFieldDismissed) {
            $0.search.isFieldOpen = false
        }
        XCTAssertEqual(store.state.search.query, "칼국")
        await store.finish()
    }

    func test_검색을_풀어도_고른_장소의_선택과_번호와_핀과_경로가_그대로다() async {
        let store = TestStore(initialState: searchedState(isFieldOpen: false, selected: ["a"])) {
            CourseFeature()
        }

        await store.send(.rowTapped("d")) {
            $0.selectedPlaceIDs = ["a", "d"]
            $0.camera = focused(searchOnlyD.place.coordinate)
        }
        await store.send(.searchChipClearTapped) {
            $0.search.query = ""
            $0.search.results = []
            $0.search.loadState = .idle
        }

        XCTAssertEqual(store.state.badgeState(for: "a"), .number(1))
        XCTAssertEqual(store.state.badgeState(for: "d"), .number(2))
        let numbered = store.state.markers.filter { $0.id.hasPrefix("numbered:") }
        XCTAssertEqual(numbered.map(\.id), ["numbered:a", "numbered:d"])
        XCTAssertEqual(numbered.map(\.kind), [.numbered(1), .numbered(2)])
        XCTAssertEqual(
            store.state.routes,
            [MapRoute(id: "course-pick", coordinates: [candidateCoordinate("a"), searchOnlyD.place.coordinate])]
        )
        await store.finish()
    }

    func test_고르기_모드는_검색으로만_찾은_장소도_올린다() async {
        let store = TestStore(
            initialState: searchedState(isFieldOpen: false, mode: .pick(existing: []))
        ) {
            CourseFeature()
        }

        await store.send(.rowTapped("d")) {
            $0.selectedPlaceIDs = ["d"]
            $0.camera = focused(searchOnlyD.place.coordinate)
        }
        await store.send(.searchChipClearTapped) {
            $0.search.query = ""
            $0.search.results = []
            $0.search.loadState = .idle
        }
        await store.send(.buildTapped)
        await store.receive(.delegate(.placesPicked([searchOnlyD])))
        await store.finish()
    }
}
