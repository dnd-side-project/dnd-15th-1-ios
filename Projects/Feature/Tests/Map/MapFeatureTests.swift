import Domain
import Feature
import SharedDesignSystem
import ThirdParty
import XCTest

@MainActor
final class MapFeatureTests: XCTestCase {
    private let savedPlaces: [SavedPlace] = [
        .fixture(id: "1", latitude: 37.3128, longitude: 126.9040),
        .fixture(id: "2", latitude: 37.3141, longitude: 126.9068),
    ]

    func test_onAppear_저장장소_상태반영() async {
        let places = savedPlaces
        let callCount = LockIsolated(0)
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = {
                callCount.withValue { $0 += 1 }
                return places
            }
            $0.coupleClient.current = { nil }
            $0.courseClient.currentCourse = { nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.savedPlacesResponse) {
            $0.places = places
            $0.loadState = .loaded
        }
        XCTAssertEqual(callCount.value, 1)
    }

    func test_markers_장소에서_파생() async {
        let places = savedPlaces
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }

        // `markers` 는 계산 프로퍼티라 TestStore 상태 비교에 안 걸린다. 따로 단언한다
        await store.send(.savedPlacesResponse(.success(places))) {
            $0.places = places
            $0.bookmarkedPlaceIDs = ["1", "2"]
            $0.loadState = .loaded
            $0.camera = .focusing(places[0].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }

        XCTAssertEqual(
            store.state.markers,
            [
                MapMarker(
                    id: "1",
                    coordinate: Coordinate(latitude: 37.3128, longitude: 126.9040),
                    kind: .category(.cafe)
                ),
                MapMarker(
                    id: "2",
                    coordinate: Coordinate(latitude: 37.3141, longitude: 126.9068),
                    kind: .category(.cafe)
                ),
            ]
        )
    }

    func test_cameraChanged_카메라갱신() async {
        let moved = MapCamera(
            center: Coordinate(latitude: 37.5006, longitude: 127.0366),
            zoomLevel: 16
        )
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }

        await store.send(.cameraChanged(moved)) {
            $0.camera = moved
        }
    }

    // MARK: - 현재 위치

    func test_위치권한이_미결정이면_권한을_요청한다() async {
        let requested = LockIsolated(0)
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.locationClient.authorization = { .notDetermined }
            $0.locationClient.requestAuthorization = {
                requested.withValue { $0 += 1 }
                return .denied
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.currentLocationTapped)
        await store.receive(\.locationAuthorizationResponse)
        await store.finish()

        XCTAssertEqual(requested.value, 1)
    }

    func test_권한요청에서_거부하면_아무것도_안한다() async {
        let coordinateCalls = LockIsolated(0)
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.locationClient.authorization = { .notDetermined }
            $0.locationClient.requestAuthorization = { .denied }
            $0.locationClient.currentCoordinate = {
                coordinateCalls.withValue { $0 += 1 }
                return Coordinate(latitude: 0, longitude: 0)
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.currentLocationTapped)
        await store.receive(\.locationAuthorizationResponse)
        await store.finish()

        XCTAssertEqual(coordinateCalls.value, 0)
        XCTAssertFalse(store.state.isLocationPermissionModalPresented)
    }

    func test_위치권한이_허용이면_내위치로_옮긴다() async {
        let here = Coordinate(latitude: 37.5665, longitude: 126.9780)
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.locationClient.authorization = { .authorized }
            $0.locationClient.currentCoordinate = { here }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.currentLocationTapped)
        await store.receive(\.locationAuthorizationResponse)
        await store.receive(\.currentLocationResponse) {
            $0.camera = MapCamera.focusing(here, zoomLevel: MapCamera.singlePlaceZoom)
        }
        XCTAssertEqual(store.state.camera.zoomLevel, 16)
    }

    func test_위치권한이_거부면_설정이동_모달이_뜬다() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.locationClient.authorization = { .denied }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.currentLocationTapped)
        await store.receive(\.locationAuthorizationResponse) {
            $0.isLocationPermissionModalPresented = true
        }

        await store.send(.permissionModalDismissed) {
            $0.isLocationPermissionModalPresented = false
        }
    }

    func test_좌표조회가_실패하면_토스트가_뜬다() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.locationClient.authorization = { .authorized }
            $0.locationClient.currentCoordinate = { throw LocationError.unavailable }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.currentLocationTapped)
        await store.receive(\.locationAuthorizationResponse)
        await store.receive(\.currentLocationResponse) {
            $0.toast = ToastState.error("현재 위치를 찾지 못했어요")
        }
        // 카메라는 안 움직인다
        XCTAssertEqual(store.state.camera, MapCamera.seoulCityHall)
    }

    func test_미결정에서_허용하면_내위치로_옮긴다() async {
        let here = Coordinate(latitude: 37.5665, longitude: 126.9780)
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.locationClient.authorization = { .notDetermined }
            $0.locationClient.requestAuthorization = { .authorized }
            $0.locationClient.currentCoordinate = { here }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.currentLocationTapped)
        await store.receive(\.locationAuthorizationResponse)
        await store.receive(\.currentLocationResponse) {
            $0.camera = MapCamera.focusing(here, zoomLevel: MapCamera.singlePlaceZoom)
        }
    }
}

@MainActor
final class MapFeatureFilterTests: XCTestCase {
    private let mixed: [SavedPlace] = [
        .fixture(id: "1", latitude: 37.31, longitude: 126.90, category: .cafe, ownership: .mine),
        .fixture(id: "2", latitude: 37.31, longitude: 126.90, category: .food, ownership: .partner),
        .fixture(id: "3", latitude: 37.31, longitude: 126.90, category: .cafe, ownership: .together),
    ]

    private func loadedStore(_ places: [SavedPlace]) -> TestStore<MapFeature.State, MapFeature.Action> {
        var state = MapFeature.State()
        state.places = places
        state.loadState = .loaded
        return TestStore(initialState: state) { MapFeature() }
    }

    func test_함께저장한이_기본이고_전부_보인다() async {
        let store = loadedStore(mixed)
        XCTAssertEqual(store.state.selectedOwnership, .together)
        XCTAssertEqual(store.state.filteredPlaces.count, 3)
        XCTAssertEqual(store.state.markers.count, 3)
    }

    func test_내가저장한은_둘다저장한것도_담는다() async {
        let store = loadedStore(mixed)
        await store.send(.ownershipSelected(.mine)) {
            $0.selectedOwnership = .mine
            $0.camera = .focusing(self.mixed[0].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
        // 둘 다 저장한 장소도 내가 저장한 것이다
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["1", "3"])
        XCTAssertEqual(store.state.markers.count, 2)
    }

    func test_상대가저장한은_둘다저장한것도_담는다() async {
        let store = loadedStore(mixed)
        await store.send(.ownershipSelected(.partner)) {
            $0.selectedOwnership = .partner
            $0.camera = .focusing(self.mixed[1].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["2", "3"])
    }

    func test_저장자를_고르면_남은_목록의_첫_행으로_간다() async {
        let store = loadedStore(mixed)
        await store.send(.ownershipSelected(.partner)) {
            $0.selectedOwnership = .partner
            $0.camera = .focusing(self.mixed[1].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
        XCTAssertEqual(store.state.filteredPlaces.first?.id, "2")
    }

    func test_저장자를_골라_목록이_비면_서울_시청으로_간다() async {
        var state = MapFeature.State()
        state.places = [mixed[0]]
        state.loadState = .loaded
        state.camera = .focusing(mixed[0].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        let store = TestStore(initialState: state) { MapFeature() }

        await store.send(.ownershipSelected(.partner)) {
            $0.selectedOwnership = .partner
            $0.camera = .seoulCityHall
        }
        XCTAssertTrue(store.state.filteredPlaces.isEmpty)
    }

    func test_카테고리를_고르면_핀과_목록이_같이_줄어든다() async {
        let store = loadedStore(mixed)
        await store.send(.categoryTapped(.cafe)) {
            $0.selectedCategory = .cafe
            $0.camera = .focusing(self.mixed[0].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["1", "3"])
        XCTAssertEqual(store.state.markers.count, store.state.filteredPlaces.count)
    }

    func test_같은_카테고리를_다시_누르면_전체로_돌아간다() async {
        let store = loadedStore(mixed)
        await store.send(.categoryTapped(.cafe)) {
            $0.selectedCategory = .cafe
            $0.camera = .focusing(self.mixed[0].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
        await store.send(.categoryTapped(.cafe)) {
            $0.selectedCategory = nil
        }
        XCTAssertEqual(store.state.filteredPlaces.count, 3)
    }

    func test_두_필터가_겹쳐서_걸린다() async {
        let store = loadedStore(mixed)
        await store.send(.ownershipSelected(.partner)) {
            $0.selectedOwnership = .partner
            $0.camera = .focusing(self.mixed[1].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
        await store.send(.categoryTapped(.cafe)) {
            $0.selectedCategory = .cafe
            $0.camera = .focusing(self.mixed[2].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
        XCTAssertEqual(store.state.filteredPlaces.map(\.id), ["3"])
    }

    func test_필터_결과가_없으면_빈상태다() async {
        let store = loadedStore(mixed)
        await store.send(.categoryTapped(.tourism)) {
            $0.selectedCategory = .tourism
        }
        XCTAssertTrue(store.state.isEmpty)
        XCTAssertFalse(store.state.hasNoSavedPlace)
    }

    func test_저장한게_아예_없으면_다른_빈상태다() async {
        let store = loadedStore([])
        XCTAssertTrue(store.state.isEmpty)
        XCTAssertTrue(store.state.hasNoSavedPlace)
    }
}

@MainActor
final class MapFeatureLoadTests: XCTestCase {
    private let places: [SavedPlace] = [
        .fixture(id: "1", latitude: 37.31, longitude: 126.90),
    ]

    func test_불러오기_실패하면_실패상태가_된다() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = { throw PlaceError.network }
            $0.coupleClient.current = { nil }
            $0.courseClient.currentCourse = { nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.savedPlacesResponse) {
            $0.loadState = .failed
            $0.toast = ToastState(
                message: "장소를 불러오지 못했어요",
                icon: .error,
                actionTitle: "다시 시도"
            )
        }
    }

    func test_다시시도를_누르면_한번_더_부른다() async {
        let callCount = LockIsolated(0)
        let loaded = places
        var state = MapFeature.State()
        state.loadState = .failed

        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = {
                callCount.withValue { $0 += 1 }
                return loaded
            }
            $0.coupleClient.current = { nil }
            $0.courseClient.currentCourse = { nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.retryTapped) {
            $0.loadState = .loading
            $0.toast = nil
        }
        await store.receive(\.savedPlacesResponse) {
            $0.loadState = .loaded
            $0.places = loaded
        }
        XCTAssertEqual(callCount.value, 1)
    }

    func test_커플이_연동되면_저장자칩이_보인다() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = { [] }
            $0.coupleClient.current = {
                CoupleStatus(
                    connected: true,
                    me: CoupleMember(nickname: "나", iconID: 1),
                    partner: CoupleMember(nickname: "둘", iconID: 1),
                    daysTogether: nil
                )
            }
            $0.courseClient.currentCourse = { nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.coupleResponse) {
            $0.isCoupleConnected = true
            $0.partnerNickname = "둘"
        }
    }

    func test_커플조회가_실패해도_목록은_뜬다() async {
        let loaded = places
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = { loaded }
            $0.coupleClient.current = { throw CoupleError.network }
            $0.courseClient.currentCourse = { nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // 두 조회는 `merge` 로 같이 떠서 도착 순서가 정해져 있지 않다. 순서 대신 끝난 상태를 본다
        await store.send(.onAppear)
        await store.finish()
        await store.skipReceivedActions()

        XCTAssertEqual(store.state.loadState, .loaded)
        XCTAssertEqual(store.state.places, loaded)
        XCTAssertFalse(store.state.isCoupleConnected)
    }

    func test_미연결이면_코스버튼이_안_보인다() async {
        let store = TestStore(initialState: MapFeature.State()) { MapFeature() }
        XCTAssertFalse(store.state.showsCourseButton)
    }

    func test_연결됐고_검색중이_아니면_코스버튼이_보인다() async {
        var state = MapFeature.State()
        state.isCoupleConnected = true
        let store = TestStore(initialState: state) { MapFeature() }
        XCTAssertTrue(store.state.showsCourseButton)
    }

    func test_연결됐어도_검색중이면_코스버튼이_안_보인다() async {
        var state = MapFeature.State()
        state.isCoupleConnected = true
        state.mode = .searchResult(query: "카페", places: [])
        let store = TestStore(initialState: state) { MapFeature() }
        XCTAssertFalse(store.state.showsCourseButton)
    }

    func test_연결됐고_예정코스가_없으면_짜러가기_문구다() async {
        var state = MapFeature.State()
        state.isCoupleConnected = true
        let store = TestStore(initialState: state) { MapFeature() }
        XCTAssertEqual(store.state.courseButtonTitle, "데이트 코스 짜러가기")
        XCTAssertTrue(store.state.showsCourseButton)
    }

    func test_연결됐고_예정코스가_있으면_보러가기_문구다() async {
        var state = MapFeature.State()
        state.isCoupleConnected = true
        state.currentCourse = mapCurrentCourse
        let store = TestStore(initialState: state) { MapFeature() }
        XCTAssertEqual(store.state.courseButtonTitle, "데이트 코스 보러가기")
        XCTAssertTrue(store.state.showsCourseButton)
    }

    func test_미연결이면_예정코스가_있어도_코스버튼이_안_보인다() async {
        var state = MapFeature.State()
        state.currentCourse = mapCurrentCourse
        let store = TestStore(initialState: state) { MapFeature() }
        XCTAssertFalse(store.state.showsCourseButton)
    }

    func test_onAppear_예정코스를_받는다() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = { [] }
            $0.coupleClient.current = { nil }
            $0.courseClient.currentCourse = { mapCurrentCourse }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.finish()
        await store.skipReceivedActions()
        XCTAssertEqual(store.state.currentCourse, mapCurrentCourse)
    }

    func test_다시시도를_누르면_예정코스도_다시_받는다() async {
        let courseCalls = LockIsolated(0)
        var state = MapFeature.State()
        state.loadState = .failed
        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = { [] }
            $0.coupleClient.current = { nil }
            $0.courseClient.currentCourse = {
                courseCalls.withValue { $0 += 1 }
                return mapCurrentCourse
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.retryTapped) {
            $0.loadState = .loading
            $0.toast = nil
        }
        await store.finish()
        await store.skipReceivedActions()
        XCTAssertEqual(store.state.currentCourse, mapCurrentCourse)
        XCTAssertEqual(courseCalls.value, 1)
    }

    func test_예정코스만_다시_받으면_장소는_안_부른다() async {
        let placeCalls = LockIsolated(0)
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savedPlaces = {
                placeCalls.withValue { $0 += 1 }
                return []
            }
            $0.courseClient.currentCourse = { mapCurrentCourse }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.currentCourseRequested)
        await store.receive(\.currentCourseResponse) {
            $0.currentCourse = mapCurrentCourse
        }
        XCTAssertEqual(placeCalls.value, 0)
    }

    func test_예정코스_조회가_실패하면_기존_값을_유지한다() async {
        var state = MapFeature.State()
        state.isCoupleConnected = true
        state.currentCourse = mapCurrentCourse
        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.courseClient.currentCourse = { throw CourseError.network }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.currentCourseRequested)
        await store.finish()
        XCTAssertEqual(store.state.currentCourse, mapCurrentCourse)
        XCTAssertEqual(store.state.courseButtonTitle, "데이트 코스 보러가기")
    }
}

@MainActor
final class MapFeatureDelegateTests: XCTestCase {
    func test_핀을_누르면_팝오버가_닫히고_상위로_올린다() async {
        var state = MapFeature.State()
        state.menuTargetPlaceID = "7"
        let store = TestStore(initialState: state) { MapFeature() }

        await store.send(.markerTapped("7")) {
            $0.menuTargetPlaceID = nil
        }
        await store.receive(\.delegate.placeDetailRequested)
    }

    func test_행을_누르면_팝오버가_닫히고_상위로_올린다() async {
        var state = MapFeature.State()
        state.menuTargetPlaceID = "7"
        let store = TestStore(initialState: state) { MapFeature() }

        await store.send(.rowTapped("7")) {
            $0.menuTargetPlaceID = nil
        }
        await store.receive(\.delegate.placeDetailRequested)
    }

    func test_수정을_고르면_팝오버가_닫히고_상위로_올린다() async {
        var state = MapFeature.State()
        state.menuTargetPlaceID = "7"
        let store = TestStore(initialState: state) { MapFeature() }

        await store.send(.editTapped("7")) {
            $0.menuTargetPlaceID = nil
        }
        await store.receive(\.delegate.aliasRequested)
    }

    func test_삭제를_고르면_팝오버가_닫히고_상위로_올린다() async {
        var state = MapFeature.State()
        state.menuTargetPlaceID = "7"
        let store = TestStore(initialState: state) { MapFeature() }

        await store.send(.deleteTapped("7")) {
            $0.menuTargetPlaceID = nil
        }
        await store.receive(\.delegate.deleteRequested)
    }

    func test_점세개를_다시_누르면_팝오버가_닫힌다() async {
        let store = TestStore(initialState: MapFeature.State()) { MapFeature() }

        await store.send(.rowMenuTapped("7")) {
            $0.menuTargetPlaceID = "7"
        }
        await store.send(.rowMenuTapped("7")) {
            $0.menuTargetPlaceID = nil
        }
    }

    func test_검색바와_코스버튼도_상위로_올린다() async {
        let store = TestStore(initialState: MapFeature.State()) { MapFeature() }

        await store.send(.searchBarTapped)
        await store.receive(\.delegate.searchRequested)

        await store.send(.courseButtonTapped)
        await store.receive(\.delegate.courseRequested)
    }

    func test_예정코스가_있으면_코스버튼은_결과화면을_올린다() async {
        var state = MapFeature.State()
        state.currentCourse = mapCurrentCourse
        let store = TestStore(initialState: state) { MapFeature() }

        await store.send(.courseButtonTapped)
        await store.receive(.delegate(.courseResultRequested(dateCourseID: mapCurrentCourse.id)))
    }
}

@MainActor
final class MapFeatureChildTests: XCTestCase {
    private var savedPlaces: [SavedPlace] {
        [
            .fixture(id: "7", latitude: 37.3, longitude: 126.9),
            .fixture(id: "8", latitude: 37.4, longitude: 126.8),
        ]
    }

    func test_행을_누르면_상세_요청을_올린다() async {
        var state = MapFeature.State()
        state.places = savedPlaces
        let store = TestStore(initialState: state) { MapFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.rowTapped("7"))
        XCTAssertNil(store.state.selectedPlace)
        await store.receive(\.delegate.placeDetailRequested)
    }

    func test_핀을_누르면_상세_요청을_올린다() async {
        var state = MapFeature.State()
        state.places = savedPlaces
        let store = TestStore(initialState: state) { MapFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.markerTapped("7"))
        XCTAssertNil(store.state.selectedPlace)
        await store.receive(\.delegate.placeDetailRequested)
    }

    func test_목록에_없는_id_여도_상세_요청을_올린다() async {
        var state = MapFeature.State()
        state.places = savedPlaces
        let store = TestStore(initialState: state) { MapFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.rowTapped("없는id"))
        XCTAssertNil(store.state.selectedPlace)
        await store.receive(\.delegate.placeDetailRequested)
    }

    func test_검색_결과에서_행을_누르면_상세_요청을_올린다() async {
        let place = Place.fixture(id: "s1", name: "검색 장소")
        var state = MapFeature.State()
        state.mode = .searchResult(query: "카페", places: [place])
        let store = TestStore(initialState: state) { MapFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.rowTapped("s1"))
        XCTAssertNil(store.state.selectedPlace)
        await store.receive(\.delegate.placeDetailRequested)
    }

    func test_수정을_누르면_별칭_요청을_올리고_팝오버가_닫힌다() async {
        var state = MapFeature.State()
        state.places = savedPlaces
        state.menuTargetPlaceID = "7"
        let store = TestStore(initialState: state) { MapFeature() }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.editTapped("7")) {
            $0.menuTargetPlaceID = nil
        }
        await store.receive(\.delegate.aliasRequested)
    }

    func test_별칭을_저장하면_목록이_바뀌고_토스트가_뜬다() async {
        var state = MapFeature.State()
        state.places = savedPlaces
        let store = TestStore(initialState: state) { MapFeature() }

        let old = savedPlaces[0]
        let updated = SavedPlace(
            place: old.place,
            ownership: old.ownership,
            alias: "우리 첫 카페",
            memo: old.memo,
            savedAt: old.savedAt
        )
        await store.send(.aliasSaved(updated)) {
            $0.places[0] = updated
            $0.toast = ToastState(message: "별칭을 저장했어요")
        }
    }

    func test_선택_핀을_누르면_요청을_안_올린다() async {
        let store = TestStore(initialState: MapFeature.State()) { MapFeature() }

        await store.send(.markerTapped(MapFeature.State.selectedMarkerID))
    }
}

@MainActor
final class MapFeatureSelectedPinTests: XCTestCase {
    private let savedPlaces: [SavedPlace] = [
        .fixture(id: "1", latitude: 37.3128, longitude: 126.9040),
        .fixture(id: "2", latitude: 37.3141, longitude: 126.9068),
    ]

    private func loadedState(selected: MapFeature.State.SelectedPlace? = nil) -> MapFeature.State {
        var state = MapFeature.State()
        state.places = savedPlaces
        state.loadState = .loaded
        state.selectedPlace = selected
        return state
    }

    func test_상세가_없으면_마커개수가_기존과_같다() async {
        let store = TestStore(initialState: loadedState()) { MapFeature() }
        XCTAssertEqual(store.state.markers.count, store.state.filteredPlaces.count)
        XCTAssertEqual(store.state.markers.map(\.kind), [.category(.cafe), .category(.cafe)])
    }

    func test_선택된_장소가_있으면_선택핀이_맨뒤에_붙는다() async {
        let selected = MapFeature.State.SelectedPlace(
            id: savedPlaces[0].id,
            coordinate: savedPlaces[0].place.coordinate
        )
        let store = TestStore(initialState: loadedState(selected: selected)) { MapFeature() }

        XCTAssertEqual(store.state.markers.count, 3)
        XCTAssertEqual(store.state.markers.last?.kind, .selected)
        XCTAssertEqual(
            store.state.markers.last?.coordinate,
            savedPlaces[0].place.coordinate
        )
    }

    func test_선택된_장소가_있어도_기존_카테고리핀은_그대로다() async {
        let before = TestStore(initialState: loadedState()) { MapFeature() }.state.markers
        let selected = MapFeature.State.SelectedPlace(
            id: savedPlaces[0].id,
            coordinate: savedPlaces[0].place.coordinate
        )
        let store = TestStore(initialState: loadedState(selected: selected)) { MapFeature() }

        XCTAssertEqual(Array(store.state.markers.dropLast()), before)
    }

    func test_선택된_장소를_지우면_선택핀이_빠진다() async {
        let selected = MapFeature.State.SelectedPlace(
            id: savedPlaces[0].id,
            coordinate: savedPlaces[0].place.coordinate
        )
        let open = TestStore(initialState: loadedState(selected: selected)) { MapFeature() }
        XCTAssertEqual(open.state.markers.count, 3)

        let closed = TestStore(initialState: loadedState()) { MapFeature() }
        XCTAssertEqual(closed.state.markers.count, 2)
        XCTAssertFalse(closed.state.markers.contains { $0.kind == .selected })    }
}

@MainActor
final class MapCameraMoveTests: XCTestCase {

    func test_저장_장소를_받으면_첫_행으로_간다() async {
        let places = PlaceFixtures.savedPlaces
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }

        await store.send(.savedPlacesResponse(.success(places))) {
            $0.places = places
            $0.bookmarkedPlaceIDs = Set(places.map(\.id))
            $0.loadState = .loaded
            $0.camera = .focusing(places[0].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
    }

    func test_저장_장소가_없으면_서울_시청으로_간다() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }

        await store.send(.savedPlacesResponse(.success([]))) {
            $0.places = []
            $0.loadState = .loaded
            $0.camera = .seoulCityHall
        }
    }

    func test_카테고리를_고르면_남은_목록의_첫_행으로_간다() async {
        let places = PlaceFixtures.savedPlaces
        var state = MapFeature.State()
        state.places = places
        state.loadState = .loaded
        let store = TestStore(initialState: state) { MapFeature() }

        let category = places[1].place.category
        await store.send(.categoryTapped(category)) {
            $0.selectedCategory = category
            $0.camera = .focusing(places[1].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
    }

    func test_행을_고르면_줌은_그대로_두고_그_장소로_간다() async {
        let places = PlaceFixtures.savedPlaces
        var state = MapFeature.State()
        state.places = places
        state.loadState = .loaded
        state.camera.zoomLevel = 12
        let store = TestStore(initialState: state) { MapFeature() }

        let target = places[1]
        await store.send(.rowTapped(target.id)) {
            $0.camera = .focusing(target.place.coordinate, zoomLevel: 12)
        }
        await store.receive(\.delegate.placeDetailRequested)
    }

    func test_핀을_고르면_줌은_그대로_두고_그_장소로_간다() async {
        let places = PlaceFixtures.savedPlaces
        var state = MapFeature.State()
        state.places = places
        state.loadState = .loaded
        state.camera.zoomLevel = 12
        let store = TestStore(initialState: state) { MapFeature() }

        let target = places[1]
        await store.send(.markerTapped(target.id)) {
            $0.camera = .focusing(target.place.coordinate, zoomLevel: 12)
        }
        await store.receive(\.delegate.placeDetailRequested)
    }

    func test_검색_결과를_적용하면_첫_결과로_여러_장소용_줌으로_간다() async {
        let results = PlaceFixtures.savedPlaces.map(\.place)
        let store = TestStore(initialState: MapFeature.State()) { MapFeature() }

        await store.send(.searchResultsApplied(query: "카페", places: results)) {
            $0.mode = .searchResult(query: "카페", places: results)
            $0.camera = .focusing(results[0].coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
    }

    func test_서울_시청은_여러_장소용_줌을_쓴다() {
        XCTAssertEqual(MapCamera.seoulCityHall.zoomLevel, MapCamera.multiPlaceZoom)
        XCTAssertEqual(MapCamera.seoulCityHall.center.latitude, 37.5665, accuracy: 0.00001)
        XCTAssertEqual(MapCamera.seoulCityHall.center.longitude, 126.9780, accuracy: 0.00001)
    }
}

private let mapCurrentCourse = DateCourseSummary(
    id: "42",
    title: "성수동 데이트",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .confirmed,
    version: 1,
    totalPlaceCount: 5
)
