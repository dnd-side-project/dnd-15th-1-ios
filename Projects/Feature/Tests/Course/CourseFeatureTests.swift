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
