//
//  PlaceDetailFeatureTests.swift
//  Dulpick
//

import ComposableArchitecture
import Domain
@testable import Feature
import SharedUtils
import XCTest

@MainActor
final class PlaceDetailFeatureTests: XCTestCase {
    func test_처음에는_저장된_상태이고_카운트는_장소값이다() {
        let state = PlaceDetailFeature.State(savedPlace: .fixture(id: "7", bookmarkCount: 124))

        XCTAssertTrue(state.isBookmarked)
        XCTAssertEqual(state.bookmarkCount, 124)
        XCTAssertEqual(state.title, "장소 7")
        XCTAssertEqual(state.id, "7")
    }

    func test_검색_장소는_별칭이_없고_북마크가_꺼져_있다() {
        let place = Place(
            id: "s1",
            kakaoPlaceID: nil,
            name: "검색 장소",
            category: .cafe,
            address: "경기도 안산시 상록구 건건동 1",
            roadAddress: "경기도 안산시 상록구 건건로 1",
            coordinate: Coordinate(latitude: 37.3, longitude: 126.9),
            bookmarkCount: 12,
            thumbnailURLs: []
        )
        let state = PlaceDetailFeature.State(place: place, query: "검색 장소")

        XCTAssertFalse(state.isBookmarked)
        XCTAssertNil(state.alias)
        XCTAssertEqual(state.title, "검색 장소")
        XCTAssertEqual(state.id, "s1")
        XCTAssertEqual(state.bookmarkCount, 12)
        XCTAssertEqual(state.place.roadAddress, place.roadAddress)
        XCTAssertEqual(state.place.address, place.address)
    }

    func test_북마크를_켜고_끄면_카운트가_오르내린다() async {
        let store = TestStore(
            initialState: PlaceDetailFeature.State(savedPlace: .fixture(id: "7", bookmarkCount: 124))
        ) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.savePlace = { _, _, _, _ in SavedPlace.mocks[0] }
            $0.placeClient.removePlace = { _ in }
        }

        await store.send(.bookmarkTapped) {
            $0.didToggleBookmark = true
            $0.isBookmarked = false
            $0.bookmarkCount = 123
        }
        await store.receive(\.delegate.bookmarkToggled)
        await store.receive(\.bookmarkRemoved)
        await store.receive(\.delegate.bookmarkRemoved)

        await store.send(.bookmarkTapped) {
            $0.isBookmarked = true
            $0.bookmarkCount = 124
        }
        await store.receive(\.delegate.bookmarkToggled)
        await store.receive(\.bookmarkSaved) {
            $0.savedServerID = SavedPlace.mocks[0].place.id
        }
        await store.receive(.delegate(.bookmarkSaved("7", SavedPlace.mocks[0])))
    }

    func test_카운트는_0_아래로_내려가지_않는다() async {
        let store = TestStore(
            initialState: PlaceDetailFeature.State(savedPlace: .fixture(id: "7", bookmarkCount: 0))
        ) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.savePlace = { _, _, _, _ in SavedPlace.mocks[0] }
            $0.placeClient.removePlace = { _ in }
        }

        await store.send(.bookmarkTapped) {
            $0.didToggleBookmark = true
            $0.isBookmarked = false
            $0.bookmarkCount = 0
        }
        await store.receive(\.delegate.bookmarkToggled)
        await store.receive(\.bookmarkRemoved)
        await store.receive(\.delegate.bookmarkRemoved)
    }

    func test_주소_펼침이_켜졌다_꺼진다() async {
        let store = TestStore(
            initialState: PlaceDetailFeature.State(savedPlace: .fixture(id: "7", bookmarkCount: 1))
        ) {
            PlaceDetailFeature()
        }

        await store.send(.addressToggled) { $0.isAddressExpanded = true }
        await store.send(.addressToggled) { $0.isAddressExpanded = false }
    }

    func test_게시물과_닫기는_상위로_올린다() async {
        let store = TestStore(
            initialState: PlaceDetailFeature.State(savedPlace: .fixture(id: "7", bookmarkCount: 1))
        ) {
            PlaceDetailFeature()
        }

        await store.send(.contentTapped("1"))
        await store.receive(\.delegate.contentSelected)

        await store.send(.closeTapped)
        await store.receive(\.delegate.closed)
    }

    func test_저장_장소로_열면_서버_상세를_부르고_네_값을_갱신한다() async {
        let saved = SavedPlace.mocks[0]
        let updated = PlaceDetail(
            place: saved.place,
            savedByMe: true,
            savedMemberCount: 77,
            ownership: .mine,
            kakaoPlaceURL: URL(string: "https://place.map.kakao.com/26338954")
        )
        let store = TestStore(initialState: PlaceDetailFeature.State(savedPlace: saved)) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.placeDetail = { _ in updated }
            $0.exploreClient.placeContents = { _, _, _ in
                ContentPage(items: [], hasNext: false, popularTags: [])
            }
        }

        await store.send(.onAppear)
        await store.receive(.detailLoaded(updated)) {
            $0.place = Place(
                id: $0.id,
                kakaoPlaceID: updated.place.kakaoPlaceID,
                name: updated.place.name,
                category: updated.place.category,
                address: updated.place.address,
                roadAddress: updated.place.roadAddress,
                coordinate: updated.place.coordinate,
                bookmarkCount: 77,
                thumbnailURLs: updated.place.thumbnailURLs
            )
            $0.bookmarkCount = 77
            $0.isBookmarked = true
            $0.kakaoPlaceURL = updated.kakaoPlaceURL
            $0.savedServerID = updated.place.id
            $0.contentsLoadState = .loading
        }
        await store.receive(\.contentsResponse) {
            $0.contentsPage = 1
            $0.hasNextContents = false
            $0.contentsLoadState = .loaded
        }
    }

    func test_검색_장소로_열면_카카오_상세를_검색어와_함께_부른다() async {
        let place = Place.mocks[0]
        let store = TestStore(
            initialState: PlaceDetailFeature.State(place: place, query: "성수 카페")
        ) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.kakaoPlaceDetail = { kakaoID, query in
                XCTAssertEqual(kakaoID, place.kakaoPlaceID ?? "")
                XCTAssertEqual(query, "성수 카페")
                return PlaceDetail(
                    place: place,
                    savedByMe: false,
                    savedMemberCount: 3,
                    ownership: nil,
                    kakaoPlaceURL: URL(string: "https://place.map.kakao.com/26338954")
                )
            }
            $0.exploreClient.placeContents = { _, _, _ in
                ContentPage(items: [], hasNext: false, popularTags: [])
            }
        }

        await store.send(.onAppear)
        await store.receive(\.detailLoaded) {
            $0.place = Place(
                id: $0.id,
                kakaoPlaceID: place.kakaoPlaceID,
                name: place.name,
                category: place.category,
                address: place.address,
                roadAddress: place.roadAddress,
                coordinate: place.coordinate,
                bookmarkCount: 3,
                thumbnailURLs: place.thumbnailURLs
            )
            $0.bookmarkCount = 3
            $0.kakaoPlaceURL = URL(string: "https://place.map.kakao.com/26338954")
            $0.serverPlaceID = 1
            $0.contentsLoadState = .loading
        }
        await store.receive(\.contentsResponse) {
            $0.contentsPage = 1
            $0.hasNextContents = false
            $0.contentsLoadState = .loaded
        }
    }

    func test_조회가_실패해도_넘겨받은_값이_남는다() async {
        let saved = SavedPlace.mocks[0]
        let store = TestStore(initialState: PlaceDetailFeature.State(savedPlace: saved)) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.placeDetail = { _ in throw PlaceError.network }
            $0.exploreClient.placeContents = { _, _, _ in
                ContentPage(items: [], hasNext: false, popularTags: [])
            }
        }

        await store.send(.onAppear)
        await store.receive(\.detailLoadFailed) {
            $0.contentsLoadState = .loading
        }
        await store.receive(\.contentsResponse) {
            $0.contentsPage = 1
            $0.hasNextContents = false
            $0.contentsLoadState = .loaded
        }
        XCTAssertEqual(store.state.place.name, saved.place.name)
    }

    func test_조회_결과가_화면_식별자를_바꾸지_않는다() async {
        let place = Place.mocks[0]
        let state = PlaceDetailFeature.State(place: place, query: "성수")
        let originalID = state.id
        let other = Place(
            id: "999999",
            kakaoPlaceID: place.kakaoPlaceID,
            name: place.name,
            category: place.category,
            address: place.address,
            roadAddress: place.roadAddress,
            coordinate: place.coordinate,
            bookmarkCount: 5,
            thumbnailURLs: place.thumbnailURLs
        )
        let store = TestStore(initialState: state) { PlaceDetailFeature() } withDependencies: {
            $0.placeClient.kakaoPlaceDetail = { _, _ in
                PlaceDetail(place: other, savedByMe: false, savedMemberCount: 5, ownership: nil)
            }
            $0.exploreClient.placeContents = { _, _, _ in
                ContentPage(items: [], hasNext: false, popularTags: [])
            }
        }

        await store.send(.onAppear)
        await store.receive(\.detailLoaded) {
            $0.place = Place(
                id: $0.id,
                kakaoPlaceID: other.kakaoPlaceID,
                name: other.name,
                category: other.category,
                address: other.address,
                roadAddress: other.roadAddress,
                coordinate: other.coordinate,
                bookmarkCount: 5,
                thumbnailURLs: other.thumbnailURLs
            )
            $0.bookmarkCount = 5
            $0.serverPlaceID = 999999
            $0.contentsLoadState = .loading
        }
        await store.receive(\.contentsResponse) {
            $0.contentsPage = 1
            $0.hasNextContents = false
            $0.contentsLoadState = .loaded
        }
        XCTAssertEqual(store.state.id, originalID)
    }
}

// 위 클래스가 type_body_length 한계라 검색 상세 서버 id 는 따로 둔다
@MainActor
final class PlaceDetailFeatureSavedServerIDTests: XCTestCase {
    func test_저장된_검색_상세는_서버id를_savedServerID로_남긴다() async {
        let serverPlace = Place.mocks[0]
        guard let kakaoID = serverPlace.kakaoPlaceID else {
            return XCTFail("mock 카카오 id")
        }
        let searchPlace = Place(
            id: kakaoID,
            kakaoPlaceID: kakaoID,
            name: serverPlace.name,
            category: serverPlace.category,
            address: serverPlace.address,
            roadAddress: serverPlace.roadAddress,
            coordinate: serverPlace.coordinate,
            bookmarkCount: serverPlace.bookmarkCount,
            thumbnailURLs: serverPlace.thumbnailURLs
        )
        let detail = PlaceDetail(
            place: serverPlace, savedByMe: true, savedMemberCount: 5, ownership: .mine
        )
        let store = TestStore(
            initialState: PlaceDetailFeature.State(place: searchPlace, query: "성수 카페")
        ) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.kakaoPlaceDetail = { _, _ in detail }
            $0.exploreClient.placeContents = { _, _, _ in
                ContentPage(items: [], hasNext: false, popularTags: [])
            }
        }

        await store.send(.onAppear)
        await store.receive(\.detailLoaded) {
            $0.place = Place(
                id: $0.id,
                kakaoPlaceID: serverPlace.kakaoPlaceID,
                name: serverPlace.name,
                category: serverPlace.category,
                address: serverPlace.address,
                roadAddress: serverPlace.roadAddress,
                coordinate: serverPlace.coordinate,
                bookmarkCount: 5,
                thumbnailURLs: serverPlace.thumbnailURLs
            )
            $0.bookmarkCount = 5
            $0.isBookmarked = true
            $0.serverPlaceID = 1
            $0.savedServerID = serverPlace.id
            $0.contentsLoadState = .loading
        }
        await store.receive(\.contentsResponse) {
            $0.contentsPage = 1
            $0.hasNextContents = false
            $0.contentsLoadState = .loaded
        }
        XCTAssertEqual(store.state.place.id, kakaoID)
        XCTAssertEqual(store.state.savedServerID, serverPlace.id)
    }
}

@MainActor
final class PlaceDetailFeatureMapTests: XCTestCase {
    func test_카카오_장소ID_가_있으면_앱_주소를_만든다() {
        let state = PlaceDetailFeature.State(savedPlace: .fixture(id: "7"))

        XCTAssertEqual(state.kakaoMapAppURL, URL(string: "kakaomap://place?id=kakao-7"))
        XCTAssertTrue(state.canOpenKakaoMap)
    }

    func test_카카오_장소ID_가_없으면_앱_주소가_없고_버튼이_안_눌린다() {
        let state = PlaceDetailFeature.State(place: .fixture(id: "s1"), query: "검색어")

        XCTAssertNil(state.kakaoMapAppURL)
        XCTAssertNil(state.kakaoMapWebURL)
        XCTAssertFalse(state.canOpenKakaoMap)
    }

    func test_서버가_준_웹_주소를_그대로_쓴다() async {
        let saved = SavedPlace.fixture(id: "7")
        let serverURL = URL(string: "https://place.map.kakao.com/26338954")
        let detail = PlaceDetail(
            place: saved.place,
            savedByMe: true,
            savedMemberCount: 1,
            ownership: .mine,
            kakaoPlaceURL: serverURL
        )
        let store = TestStore(initialState: PlaceDetailFeature.State(savedPlace: saved)) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.placeDetail = { _ in detail }
            $0.exploreClient.placeContents = { _, _, _ in
                ContentPage(items: [], hasNext: false, popularTags: [])
            }
        }

        await store.send(.onAppear)
        await store.receive(\.detailLoaded) {
            $0.place = Place(
                id: $0.id,
                kakaoPlaceID: detail.place.kakaoPlaceID,
                name: detail.place.name,
                category: detail.place.category,
                address: detail.place.address,
                roadAddress: detail.place.roadAddress,
                coordinate: detail.place.coordinate,
                bookmarkCount: 1,
                thumbnailURLs: detail.place.thumbnailURLs
            )
            $0.bookmarkCount = 1
            $0.kakaoPlaceURL = serverURL
            $0.savedServerID = detail.place.id
            $0.contentsLoadState = .loading
        }
        await store.receive(\.contentsResponse) {
            $0.contentsPage = 1
            $0.hasNextContents = false
            $0.contentsLoadState = .loaded
        }

        XCTAssertEqual(store.state.kakaoMapWebURL, serverURL)
    }

    func test_서버가_웹_주소를_안_주면_장소ID_로_만든다() {
        let state = PlaceDetailFeature.State(savedPlace: .fixture(id: "7"))

        XCTAssertNil(state.kakaoPlaceURL)
        XCTAssertEqual(
            state.kakaoMapWebURL,
            URL(string: "https://place.map.kakao.com/kakao-7")
        )
    }

    func test_조회가_실패하면_웹_주소를_장소ID_로_만든다() async {
        let store = TestStore(
            initialState: PlaceDetailFeature.State(savedPlace: .fixture(id: "7"))
        ) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.placeDetail = { _ in throw PlaceError.network }
            $0.exploreClient.placeContents = { _, _, _ in
                ContentPage(items: [], hasNext: false, popularTags: [])
            }
        }

        await store.send(.onAppear)
        await store.receive(\.detailLoadFailed) {
            $0.contentsLoadState = .loading
        }
        await store.receive(\.contentsResponse) {
            $0.contentsPage = 1
            $0.hasNextContents = false
            $0.contentsLoadState = .loaded
        }

        XCTAssertNil(store.state.kakaoPlaceURL)
        XCTAssertEqual(
            store.state.kakaoMapWebURL,
            URL(string: "https://place.map.kakao.com/kakao-7")
        )
    }

    func test_앱_주소가_없어도_웹_주소가_있으면_버튼이_눌린다() {
        var state = PlaceDetailFeature.State(place: .fixture(id: "s1"), query: "검색어")
        state.kakaoPlaceURL = URL(string: "https://place.map.kakao.com/26338954")

        XCTAssertNil(state.kakaoMapAppURL)
        XCTAssertEqual(state.kakaoMapWebURL, URL(string: "https://place.map.kakao.com/26338954"))
        XCTAssertTrue(state.canOpenKakaoMap)
    }
}

@MainActor
final class PlaceDetailFeatureContentsTests: XCTestCase {
    private func page(_ ids: [String], hasNext: Bool) -> ContentPage {
        ContentPage(
            items: ids.map { Content(id: $0, title: "게시물 \($0)", thumbnailURLs: [], placeCount: 1) },
            hasNext: hasNext,
            popularTags: []
        )
    }

    func test_상세_조회가_끝나면_게시물_첫_장을_부른다() async {
        let saved = SavedPlace.fixture(id: "7")
        let detail = PlaceDetail(
            place: saved.place, savedByMe: true, savedMemberCount: 1, ownership: .mine
        )
        let first = page(["1", "2", "3", "4"], hasNext: true)
        let store = TestStore(initialState: PlaceDetailFeature.State(savedPlace: saved)) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.placeDetail = { _ in detail }
            $0.exploreClient.placeContents = { placeID, page, size in
                XCTAssertEqual(placeID, 7)
                XCTAssertEqual(page, 0)
                XCTAssertEqual(size, 4)
                return first
            }
        }

        await store.send(.onAppear)
        await store.receive(\.detailLoaded) {
            $0.place = Place(
                id: $0.id,
                kakaoPlaceID: detail.place.kakaoPlaceID,
                name: detail.place.name,
                category: detail.place.category,
                address: detail.place.address,
                roadAddress: detail.place.roadAddress,
                coordinate: detail.place.coordinate,
                bookmarkCount: 1,
                thumbnailURLs: detail.place.thumbnailURLs
            )
            $0.bookmarkCount = 1
            $0.savedServerID = detail.place.id
            $0.contentsLoadState = .loading
        }
        await store.receive(\.contentsResponse) {
            $0.contents = first.items
            $0.hasNextContents = true
            $0.contentsPage = 1
            $0.contentsLoadState = .loaded
        }
    }

    func test_더보기가_다음_장을_이어_붙인다() async {
        let saved = SavedPlace.fixture(id: "7")
        let second = page(["5", "6"], hasNext: false)
        var state = PlaceDetailFeature.State(savedPlace: saved)
        state.contents = page(["1", "2", "3", "4"], hasNext: true).items
        state.contentsPage = 1
        state.contentsLoadState = .loaded
        let store = TestStore(initialState: state) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.exploreClient.placeContents = { _, page, _ in
                XCTAssertEqual(page, 1)
                return second
            }
        }

        await store.send(.moreTapped) { $0.contentsLoadState = .loading }
        await store.receive(\.contentsResponse) {
            $0.contents += second.items
            $0.hasNextContents = false
            $0.contentsPage = 2
            $0.contentsLoadState = .loaded
        }
        XCTAssertEqual(store.state.contents.count, 6)
    }

    func test_다음_장이_없으면_더보기가_아무것도_안_한다() async {
        var state = PlaceDetailFeature.State(savedPlace: .fixture(id: "7"))
        state.contentsLoadState = .loaded
        state.hasNextContents = false
        let store = TestStore(initialState: state) { PlaceDetailFeature() }

        await store.send(.moreTapped)
    }

    func test_게시물_조회가_실패하면_실패_상태가_된다() async {
        let saved = SavedPlace.fixture(id: "7")
        let detail = PlaceDetail(
            place: saved.place, savedByMe: true, savedMemberCount: 1, ownership: .mine
        )
        let store = TestStore(initialState: PlaceDetailFeature.State(savedPlace: saved)) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.placeDetail = { _ in detail }
            $0.exploreClient.placeContents = { _, _, _ in throw ExploreError.network }
        }

        await store.send(.onAppear)
        await store.receive(\.detailLoaded) {
            $0.place = Place(
                id: $0.id,
                kakaoPlaceID: detail.place.kakaoPlaceID,
                name: detail.place.name,
                category: detail.place.category,
                address: detail.place.address,
                roadAddress: detail.place.roadAddress,
                coordinate: detail.place.coordinate,
                bookmarkCount: 1,
                thumbnailURLs: detail.place.thumbnailURLs
            )
            $0.bookmarkCount = 1
            $0.savedServerID = detail.place.id
            $0.contentsLoadState = .loading
        }
        await store.receive(\.contentsLoadFailed) { $0.contentsLoadState = .failed }
    }

    func test_다시_시도를_누르면_다시_부른다() async {
        var state = PlaceDetailFeature.State(savedPlace: .fixture(id: "7"))
        state.contentsLoadState = .failed
        let recovered = page(["1"], hasNext: false)
        let store = TestStore(initialState: state) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.exploreClient.placeContents = { _, _, _ in recovered }
        }

        await store.send(.retryContentsTapped) { $0.contentsLoadState = .loading }
        await store.receive(\.contentsResponse) {
            $0.contents = recovered.items
            $0.hasNextContents = false
            $0.contentsPage = 1
            $0.contentsLoadState = .loaded
        }
    }

    func test_서버_ID_가_없으면_게시물을_안_부른다() async {
        let place = Place.fixture(id: "s1")
        let store = TestStore(
            initialState: PlaceDetailFeature.State(place: place, query: "검색어")
        ) {
            PlaceDetailFeature()
        }

        XCTAssertNil(store.state.serverPlaceID)

        await store.send(.moreTapped)
    }

    func test_상세_조회가_실패해도_아는_서버_ID_로_게시물을_부른다() async {
        let saved = SavedPlace.fixture(id: "7")
        let loaded = page(["1"], hasNext: false)
        let store = TestStore(initialState: PlaceDetailFeature.State(savedPlace: saved)) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.placeDetail = { _ in throw PlaceError.network }
            $0.exploreClient.placeContents = { _, _, _ in loaded }
        }

        await store.send(.onAppear)
        await store.receive(\.detailLoadFailed) {
            $0.contentsLoadState = .loading
        }
        await store.receive(\.contentsResponse) {
            $0.contents = loaded.items
            $0.hasNextContents = false
            $0.contentsPage = 1
            $0.contentsLoadState = .loaded
        }
    }

    func test_서버가_모르는_카카오_장소는_게시물을_안_부른다() async {
        let place = Place(
            id: "26338954",
            kakaoPlaceID: "26338954",
            name: "검색 장소",
            category: .cafe,
            address: "서울특별시 성동구 성수동1가 685-700",
            roadAddress: "서울특별시 성동구 서울숲2길 10",
            coordinate: Coordinate(latitude: 37.5446, longitude: 127.0557),
            bookmarkCount: 0,
            thumbnailURLs: []
        )
        let detail = PlaceDetail(
            place: place, savedByMe: false, savedMemberCount: 0, ownership: nil
        )
        let store = TestStore(
            initialState: PlaceDetailFeature.State(place: place, query: "성수 카페")
        ) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.kakaoPlaceDetail = { _, _ in detail }
        }

        await store.send(.onAppear)
        await store.receive(\.detailLoaded)

        XCTAssertNil(store.state.serverPlaceID)
        XCTAssertTrue(store.state.contents.isEmpty)
    }

    func test_이미_부르는_중이면_더보기가_다시_안_부른다() async {
        var state = PlaceDetailFeature.State(savedPlace: .fixture(id: "7"))
        state.contentsLoadState = .loading
        let store = TestStore(initialState: state) { PlaceDetailFeature() }

        await store.send(.moreTapped)
    }
}
