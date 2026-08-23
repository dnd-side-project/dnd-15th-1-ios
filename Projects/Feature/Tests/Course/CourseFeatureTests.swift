import ComposableArchitecture
import Domain
import Feature
import SharedDesignSystem
import XCTest

@MainActor
final class CourseDateInputTests: XCTestCase {

    func test_날짜없이_다음_에러표시() async {
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nextTapped) {
            $0.showsDateError = true
        }
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
                    scheduledAt: Date(timeIntervalSince1970: 0),
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
        }
        await store.send(.wheelDraftChanged(DateComponents(year: 2030, month: 8, day: 5))) {
            $0.draftDate = DateComponents(year: 2030, month: 8, day: 5)
        }
        await store.send(.wheelConfirmed) {
            $0.date = DateComponents(year: 2030, month: 8, day: 5)
            $0.activeWheel = nil
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
                    scheduledAt: Date(timeIntervalSince1970: 0),
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

    func test_다음을_누르면_코스를_만들고_ID를_들고_넘어간다() async {
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.courseClient.createCourse = { title, date, time in
                XCTAssertEqual(title, "30.08.05 데이트")
                XCTAssertEqual(date.day, 5)
                XCTAssertEqual(time.hour, 13)
                return DateCourse(
                    id: "42",
                    title: title,
                    scheduledAt: Date(timeIntervalSince1970: 0),
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

    func test_시간을_안_고르면_오후_한시를_보낸다() async {
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.courseClient.createCourse = { _, _, time in
                XCTAssertEqual(time.hour, 13)
                XCTAssertEqual(time.minute, 0)
                return DateCourse(
                    id: "1",
                    title: "t",
                    scheduledAt: Date(timeIntervalSince1970: 0),
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
        await store.send(.nextTapped)
        await store.receive(\.courseCreated)
        await store.receive(.delegate(.placePickRequested(dateCourseID: "1")))
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
        }
        await store.send(.wheelDraftChanged(DateComponents(hour: 15, minute: 30))) {
            $0.draftTime = DateComponents(hour: 15, minute: 30)
        }
        await store.send(.wheelDismissed) {
            $0.activeWheel = nil
        }
        XCTAssertNil(store.state.time)
    }
}

@MainActor
final class CoursePlacePickTests: XCTestCase {
    private let savedPlaces: [CoursePlaceCandidate] = [
        .courseFixture(id: "a", latitude: 37.31, longitude: 126.90),
        .courseFixture(id: "b", latitude: 37.32, longitude: 126.91),
        .courseFixture(id: "c", latitude: 37.33, longitude: 126.92),
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

    func test_핀탭_행탭과같다() async {
        let store = loadedStore()

        await store.send(.markerTapped("a")) { $0.selectedPlaceIDs = ["a"] }
        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = [] }

        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = ["a"] }
        await store.send(.markerTapped("a")) { $0.selectedPlaceIDs = [] }
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

    func test_고른장소_카테고리핀_위에_물방울겹침() async {
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
            ["a", "b", "c", "candidate:a", "candidate:c"]
        )
        XCTAssertEqual(
            store.state.markers.map(\.kind),
            [.category(.food), .category(.food), .category(.food), .candidate, .candidate]
        )
    }

    func test_고른장소_필터밖_물방울핀남음() async {
        let places: [CoursePlaceCandidate] = [
            .courseFixture(id: "a", latitude: 37.31, longitude: 126.90, category: .food),
            .courseFixture(id: "b", latitude: 37.32, longitude: 126.91, category: .cafe),
        ]
        var initial = CourseFeature.State()
        initial.places = places
        initial.loadState = .loaded
        let store = TestStore(initialState: initial) { CourseFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = ["a"] }
        await store.send(.categoryTapped(.cafe)) { $0.selectedCategory = .cafe }

        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["b"])
        XCTAssertEqual(store.state.markers.map(\.id), ["b", "candidate:a"])
        XCTAssertEqual(
            store.state.markers.map(\.kind),
            [.category(.cafe), .candidate]
        )
    }

    func test_물방울핀탭_고른장소_해제() async {
        let store = loadedStore()

        await store.send(.rowTapped("a")) { $0.selectedPlaceIDs = ["a"] }
        await store.send(.markerTapped("candidate:a")) { $0.selectedPlaceIDs = [] }
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
            scheduledAt: Date(timeIntervalSince1970: 0),
            status: .confirmed,
            version: 1,
            stops: [],
            legs: []
        )
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.updateCourse = { _, _, _, _, _ in saved }
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
final class CourseLoadTests: XCTestCase {

    func test_onAppear_저장장소_상태반영() async {
        let places: [CoursePlaceCandidate] = [.courseFixture(id: "a", latitude: 37.31, longitude: 126.90)]
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.coursePlaces = { places }
            $0.coupleClient.current = { nil }
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
        let places: [CoursePlaceCandidate] = [.courseFixture(id: "a", latitude: 37.31, longitude: 126.90)]
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.courseClient.coursePlaces = {
                if shouldFail.value { throw CourseError.network }
                return places
            }
            $0.coupleClient.current = { nil }
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
        let status = CoupleStatus(
            connected: true,
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
            $0.coupleClient.current = { nil }
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
        let places: [CoursePlaceCandidate] = [
            .courseFixture(id: "a", latitude: 37.31, longitude: 126.90, category: .food),
            .courseFixture(id: "b", latitude: 37.32, longitude: 126.91, category: .cafe),
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
        let places: [CoursePlaceCandidate] = [
            .courseFixture(id: "a", latitude: 37.31, longitude: 126.90, category: .food, ownership: .mine),
            .courseFixture(id: "b", latitude: 37.32, longitude: 126.91, category: .cafe, ownership: .partner),
            .courseFixture(id: "c", latitude: 37.33, longitude: 126.92, category: .food, ownership: .together),
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

private extension CoursePlaceCandidate {
    static func courseFixture(
        id: String,
        latitude: Double,
        longitude: Double,
        category: PlaceCategory = .food,
        ownership: PlaceOwnership = .together
    ) -> CoursePlaceCandidate {
        CoursePlaceCandidate(
            id: id,
            name: "장소명",
            address: "경기도 안산시 모모로 145길",
            category: category,
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            ownership: ownership,
            alias: nil,
            thumbnailURLs: []
        )
    }
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
            $0.camera = .focusing(candidates[0].coordinate, zoomLevel: MapCamera.multiPlaceZoom)
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
}

@MainActor
final class CourseSaveTests: XCTestCase {
    private let savedPlaces: [CoursePlaceCandidate] = [
        .courseFixture(id: "a", latitude: 37.31, longitude: 126.90),
        .courseFixture(id: "b", latitude: 37.32, longitude: 126.91),
    ]

    private var confirmedCourse: DateCourse {
        DateCourse(
            id: "42",
            title: "30.08.05 데이트",
            scheduledAt: Date(timeIntervalSince1970: 0),
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
        store.dependencies.courseClient.updateCourse = { id, title, _, placeIDs, version in
            XCTAssertEqual(id, "42")
            XCTAssertEqual(title, "30.08.05 데이트")
            XCTAssertEqual(placeIDs, ["a", "b"])
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

    func test_저장이_409면_다시_읽고_알린다() async {
        let latest = DateCourse(
            id: "42",
            title: "30.08.05 데이트",
            scheduledAt: Date(timeIntervalSince1970: 0),
            status: .confirmed,
            version: 2,
            stops: [],
            legs: []
        )
        let store = placePickStore()
        store.dependencies.courseClient.updateCourse = { _, _, _, _, _ in throw CourseError.conflict }
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
        store.dependencies.courseClient.updateCourse = { _, _, _, _, _ in throw CourseError.conflict }
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
        store.dependencies.courseClient.updateCourse = { _, _, _, _, _ in throw CourseError.network }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        await store.receive(\.courseSaved.failure) {
            $0.isSavingCourse = false
            $0.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
        }
    }

    func test_저장이_인증만료면_상위로_올린다() async {
        let store = placePickStore()
        store.dependencies.courseClient.updateCourse = { _, _, _, _, _ in throw CourseError.unauthorized }
        await store.send(.buildTapped) { $0.isSavingCourse = true }
        await store.receive(\.courseSaved.failure) {
            $0.isSavingCourse = false
        }
        await store.receive(.delegate(.sessionExpired))
        XCTAssertNil(store.state.toast)
    }

    func test_저장_중_뒤로가면_저장을_끊는다() async {
        let store = placePickStore()
        store.dependencies.courseClient.updateCourse = { _, _, _, _, _ in
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
        store.dependencies.courseClient.updateCourse = { _, _, _, _, _ in throw CourseError.conflict }
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
