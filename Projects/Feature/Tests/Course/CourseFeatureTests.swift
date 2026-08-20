import ComposableArchitecture
import Domain
import Feature
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
        await store.receive(.delegate(.placePickRequested))
    }

    func test_시간없이_다음_통과() async {
        var initial = CourseFeature.State()
        initial.date = DateComponents(year: 2030, month: 8, day: 5)
        let store = TestStore(initialState: initial) {
            CourseFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nextTapped)
        await store.receive(.delegate(.placePickRequested))
        XCTAssertNil(store.state.time)
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
    private let savedPlaces: [SavedPlace] = [
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
        let places: [SavedPlace] = [
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
        let store = TestStore(initialState: initial) { CourseFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.buildTapped)
        await store.receive(
            .delegate(
                .buildRequested(
                    date: DateComponents(year: 2030, month: 8, day: 5),
                    time: DateComponents(hour: 13, minute: 0),
                    placeIDs: ["a", "b"]
                )
            )
        )
    }
}

@MainActor
final class CourseLoadTests: XCTestCase {

    func test_onAppear_저장장소_상태반영() async {
        let places: [SavedPlace] = [.courseFixture(id: "a", latitude: 37.31, longitude: 126.90)]
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = { places }
            $0.coupleClient.current = { nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.savedPlacesResponse) {
            $0.places = places
            $0.loadState = .loaded
        }
    }

    func test_로드실패_재시도() async {
        let shouldFail = LockIsolated(true)
        let places: [SavedPlace] = [.courseFixture(id: "a", latitude: 37.31, longitude: 126.90)]
        let store = TestStore(initialState: CourseFeature.State()) {
            CourseFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = {
                if shouldFail.value { throw PlaceError.network }
                return places
            }
            $0.coupleClient.current = { nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.savedPlacesResponse) {
            $0.loadState = .failed
        }

        shouldFail.withValue { $0 = false }
        await store.send(.retryTapped) {
            $0.loadState = .loading
        }
        await store.receive(\.savedPlacesResponse) {
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
            $0.placeClient.savedPlaces = { [] }
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
            $0.placeClient.savedPlaces = { [] }
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
        let places: [SavedPlace] = [
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
        let places: [SavedPlace] = [
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

@MainActor
final class MapFlowCourseWiringTests: XCTestCase {

    func test_코스요청_날짜화면_push() async {
        let store = TestStore(initialState: MapFlowFeature.State()) {
            MapFlowFeature()
        }

        await store.send(.map(.delegate(.courseRequested))) {
            $0.course = CourseFeature.State()
            $0.path = [.course]
        }
    }

    func test_날짜검증통과_장소선택_push() async {
        var course = CourseFeature.State()
        course.date = DateComponents(year: 2030, month: 8, day: 5)
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: course,
                path: [.course]
            )
        ) {
            MapFlowFeature()
        }

        await store.send(.course(.nextTapped))
        await store.receive(\.course.delegate.placePickRequested) {
            $0.path = [.course, .coursePlacePick]
        }
    }

    func test_코스짜기_delegate_삼킴() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: CourseFeature.State(),
                path: [.course, .coursePlacePick]
            )
        ) {
            MapFlowFeature()
        }

        // Cycle 5 가 코스 결과 화면을 붙이기 전까지는 아무 일도 안 일어난다
        await store.send(
            .course(
                .delegate(
                    .buildRequested(
                        date: DateComponents(year: 2030, month: 8, day: 5),
                        time: nil,
                        placeIDs: ["a"]
                    )
                )
            )
        )
    }

    func test_경로가_비면_코스State_nil() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: CourseFeature.State(),
                path: [.course]
            )
        ) {
            MapFlowFeature()
        }

        await store.send(.pathChanged([])) {
            $0.path = []
            $0.course = nil
        }
    }
}

// MARK: - Fixture

private extension SavedPlace {
    static func courseFixture(
        id: String,
        latitude: Double,
        longitude: Double,
        category: PlaceCategory = .food,
        ownership: PlaceOwnership = .together
    ) -> SavedPlace {
        SavedPlace(
            place: Place(
                id: id,
                kakaoPlaceID: nil,
                name: "장소명",
                category: category,
                address: "경기도 안산시 모모로 145길",
                roadAddress: "경기도 안산시 모모로 145길",
                coordinate: Coordinate(latitude: latitude, longitude: longitude),
                bookmarkCount: 0,
                thumbnailURLs: []
            ),
            ownership: ownership,
            alias: nil,
            memo: nil,
            savedAt: nil
        )
    }
}
