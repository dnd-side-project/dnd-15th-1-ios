import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class MapFlowPlaceSearchTests: XCTestCase {
    func test_검색바를_누르면_검색화면이_열린다() async {
        let store = TestStore(initialState: MapFlowFeature.State()) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.map(.delegate(.searchRequested))) {
            $0.placeSearch = PlaceSearchFeature.State()
            $0.path = [.search]
        }
    }

    func test_다시열기를_받으면_검색어가_채워진_검색화면이_열린다() async {
        let store = TestStore(initialState: MapFlowFeature.State()) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.map(.delegate(.searchReopenRequested(query: "음식점")))) {
            $0.placeSearch = PlaceSearchFeature.State(query: "음식점")
            $0.path = [.search]
        }
    }

    func test_뒤로가면_검색화면이_닫힌다() async {
        var state = MapFlowFeature.State()
        state.placeSearch = PlaceSearchFeature.State()
        state.path = [.search]

        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.placeSearch(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchClearTapped)
    }

    func test_엔터하면_닫고_지도에_결과를_넘긴다() async {
        let results = [PlaceSearchResult.unsaved(.fixture(id: "s1", latitude: 37.5, longitude: 127.0))]
        var state = MapFlowFeature.State()
        state.placeSearch = PlaceSearchFeature.State()
        state.path = [.search]

        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.placeSearch(.delegate(.searchConfirmed(query: "음식점", results: results, isSavedOnly: false))))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchResultsApplied) {
            $0.map.mode = .searchResult(query: "음식점", results: results, isSavedOnly: false)
        }
    }

    func test_엔터로_닫혀도_최근검색어가_저장된다() async {
        let results = [PlaceSearchResult.unsaved(.fixture(id: "s1", latitude: 37.5, longitude: 127.0))]
        var search = PlaceSearchFeature.State()
        search.query = "음식점"
        search.results = results
        search.loadState = .loaded

        var state = MapFlowFeature.State()
        state.placeSearch = search
        state.path = [.search]

        let callCount = LockIsolated(0)
        let store = TestStore(initialState: state) {
            MapFlowFeature()
        } withDependencies: {
            $0.mapRecentSearchClient.add = { term in
                callCount.withValue { $0 += 1 }
                return [term]
            }
        }
        store.exhaustivity = .off

        await store.send(.placeSearch(.submitted))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchResultsApplied) {
            $0.map.mode = .searchResult(query: "음식점", results: results, isSavedOnly: false)
        }
        XCTAssertEqual(callCount.value, 1)
    }

    func test_검색결과에서_뒤로가면_저장장소로_빠져나온다() async {
        let results = [PlaceSearchResult.unsaved(.fixture(id: "s1", latitude: 37.5, longitude: 127.0))]
        var state = MapFlowFeature.State()
        state.placeSearch = PlaceSearchFeature.State()
        state.path = [.search]

        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.placeSearch(.delegate(.searchConfirmed(query: "음식점", results: results, isSavedOnly: false))))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchResultsApplied) {
            $0.map.mode = .searchResult(query: "음식점", results: results, isSavedOnly: false)
        }

        await store.send(.map(.searchBackTapped))
        await store.receive(\.map.delegate.searchReopenRequested) {
            $0.placeSearch = PlaceSearchFeature.State(query: "음식점")
            $0.path = [.search]
        }

        await store.send(.placeSearch(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchClearTapped) {
            $0.map.mode = .saved
        }
    }

    func test_검색결과_행을_누르면_지도에_올리고_상세를_연다() async {
        let place = Place.fixture(id: "p1", name: "고른 장소")
        var state = MapFlowFeature.State()
        state.placeSearch = PlaceSearchFeature.State()
        state.path = [.search]

        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.placeSearch(.delegate(.placeSelected(.unsaved(place), query: "고른 장소")))) {
            $0.detail = PlaceDetailFeature.State(place: place, query: "고른 장소")
            $0.map.selectedPlace = MapFeature.State.SelectedPlace(
                id: place.id,
                coordinate: place.coordinate
            )
        }
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchResultsApplied) {
            $0.map.mode = .searchResult(query: "고른 장소", results: [.unsaved(place)], isSavedOnly: false)
            $0.map.camera.center = place.coordinate
        }
        // 화면 등장에 안 기댄다. 흐름이 상세의 조회를 직접 시작한다
        await store.receive(\.detail.presented.onAppear)
    }
}

/// 커플 저장 장소 검색이 주는 한 건과 그 장소의 상세 조회 응답
private enum SavedOnlySearchFixture {
    /// 카카오 번호가 없고 별칭이 있다
    static let saved = SavedPlace(
        place: SavedPlace.candidateFixture(id: "3").place,
        ownership: .partner,
        alias: "우리 카페",
        memo: nil,
        savedAt: nil
    )
    /// 검색 결과에 없던 카카오 번호가 채워진다. 상대만 저장해 내 저장 여부는 false 다
    static let detail = PlaceDetail(
        place: SavedPlace.fixture(id: "3").place,
        isSaved: false,
        ownership: .partner
    )
}

@MainActor
final class MapFlowSavedOnlySearchTests: XCTestCase {
    func test_저장_목록에서_검색_버튼으로_열면_토글이_꺼진_채_커플_여부를_넘긴다() async {
        var map = MapFeature.State()
        map.isCoupleConnected = true
        let store = TestStore(initialState: MapFlowFeature.State(map: map)) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.map(.searchBarTapped))
        await store.receive(\.map.delegate.searchRequested) {
            $0.placeSearch = PlaceSearchFeature.State(isSavedOnly: false, isCoupleConnected: true)
            $0.path = [.search]
        }
    }

    func test_토글_결과에서_검색창을_누르면_토글을_이어받는다() async {
        var map = MapFeature.State()
        map.isCoupleConnected = true
        map.mode = .searchResult(
            query: "성수",
            results: [PlaceSearchResult(savedPlace: SavedOnlySearchFixture.saved)],
            isSavedOnly: true
        )
        let store = TestStore(initialState: MapFlowFeature.State(map: map)) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.map(.searchBarTapped))
        await store.receive(\.map.delegate.searchRequested) {
            $0.placeSearch = PlaceSearchFeature.State(isSavedOnly: true, isCoupleConnected: true)
            $0.path = [.search]
        }
    }

    func test_토글_결과에서_뒤로가면_검색어와_토글을_이어받는다() async {
        var map = MapFeature.State()
        map.isCoupleConnected = true
        map.mode = .searchResult(
            query: "성수",
            results: [PlaceSearchResult(savedPlace: SavedOnlySearchFixture.saved)],
            isSavedOnly: true
        )
        let store = TestStore(initialState: MapFlowFeature.State(map: map)) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.map(.searchBackTapped))
        await store.receive(\.map.delegate.searchReopenRequested) {
            $0.placeSearch = PlaceSearchFeature.State(query: "성수", isSavedOnly: true, isCoupleConnected: true)
            $0.path = [.search]
        }
    }

    func test_토글_결과로_엔터하면_지도에_토글_상태째_깐다() async {
        let results = [PlaceSearchResult(savedPlace: SavedOnlySearchFixture.saved)]
        var state = MapFlowFeature.State()
        state.placeSearch = PlaceSearchFeature.State(query: "성수", isSavedOnly: true, isCoupleConnected: true)
        state.path = [.search]
        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.placeSearch(.delegate(.searchConfirmed(query: "성수", results: results, isSavedOnly: true))))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchResultsApplied) {
            $0.map.mode = .searchResult(query: "성수", results: results, isSavedOnly: true)
        }
    }

    func test_검색_화면에서_토글_결과를_고르면_저장_목록처럼_상세가_채워진다() async {
        let saved = SavedOnlySearchFixture.saved
        var state = MapFlowFeature.State()
        state.placeSearch = PlaceSearchFeature.State(query: "성수", isSavedOnly: true, isCoupleConnected: true)
        state.path = [.search]
        let requestedID = LockIsolated<String?>(nil)
        let store = TestStore(initialState: state) {
            MapFlowFeature()
        } withDependencies: {
            $0.placeClient.placeDetail = { placeID in
                requestedID.setValue(placeID)
                return SavedOnlySearchFixture.detail
            }
            $0.contentClient.placeContents = { _, _, _ in ContentPage(items: [], hasNext: false) }
        }
        store.exhaustivity = .off

        // 저장 목록에서 연 것처럼 북마크가 켜진 채로 열린다
        await store.send(.placeSearch(.delegate(.savedPlaceSelected(saved)))) {
            $0.detail = PlaceDetailFeature.State(savedPlace: saved)
        }
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchResultsApplied) {
            $0.map.mode = .searchResult(
                query: saved.place.name,
                results: [PlaceSearchResult(savedPlace: saved)],
                isSavedOnly: true
            )
        }
        await store.receive(\.detail.presented.onAppear)
        await store.receive(\.detail.presented.detailLoaded)

        XCTAssertEqual(requestedID.value, "3")
        XCTAssertEqual(store.state.detail?.title, "우리 카페")
        XCTAssertEqual(store.state.detail?.place.kakaoPlaceID, "kakao-3")
    }

    func test_토글_결과_시트_행을_누르면_저장_목록처럼_상세가_채워지고_별칭을_보인다() async {
        let saved = SavedOnlySearchFixture.saved
        var map = MapFeature.State()
        map.mode = .searchResult(query: "성수", results: [PlaceSearchResult(savedPlace: saved)], isSavedOnly: true)
        map.bookmarkedPlaceIDs = [saved.id]
        let requestedID = LockIsolated<String?>(nil)
        let store = TestStore(initialState: MapFlowFeature.State(map: map)) {
            MapFlowFeature()
        } withDependencies: {
            $0.placeClient.placeDetail = { placeID in
                requestedID.setValue(placeID)
                return SavedOnlySearchFixture.detail
            }
            $0.contentClient.placeContents = { _, _, _ in ContentPage(items: [], hasNext: false) }
        }
        store.exhaustivity = .off

        await store.send(.map(.rowTapped(saved.id)))
        await store.receive(\.map.delegate.placeDetailRequested) {
            $0.detail = PlaceDetailFeature.State(savedPlace: saved)
        }
        await store.receive(\.detail.presented.onAppear)
        await store.receive(\.detail.presented.detailLoaded)

        XCTAssertEqual(requestedID.value, "3")
        XCTAssertEqual(store.state.detail?.title, "우리 카페")
        XCTAssertEqual(store.state.detail?.place.kakaoPlaceID, "kakao-3")
    }
}
