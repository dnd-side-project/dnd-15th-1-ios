//
//  PlaceDetailFeatureTests.swift
//  Dulpick
//

import ComposableArchitecture
import Domain
import XCTest

@testable import Feature

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

        await store.send(.bookmarkTapped) {
            $0.isBookmarked = true
            $0.bookmarkCount = 124
        }
        await store.receive(\.delegate.bookmarkToggled)
        await store.receive(\.bookmarkSaved) {
            $0.savedServerID = SavedPlace.mocks[0].place.id
        }
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

    func test_처음에는_게시물_네개만_보이고_더보기가_있다() {
        let state = PlaceDetailFeature.State(savedPlace: .fixture(id: "7", bookmarkCount: 1))

        XCTAssertEqual(state.visibleContents.count, 4)
        XCTAssertTrue(state.canLoadMore)
    }

    func test_더보기를_누르면_네개가_늘고_버튼이_사라진다() async {
        let store = TestStore(
            initialState: PlaceDetailFeature.State(savedPlace: .fixture(id: "7", bookmarkCount: 1))
        ) {
            PlaceDetailFeature()
        }

        await store.send(.moreTapped) { $0.visibleContentCount = 8 }
        XCTAssertEqual(store.state.visibleContents.count, 8)
        XCTAssertFalse(store.state.canLoadMore)
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

    func test_게시물_mock_은_여덟개다() {
        XCTAssertEqual(RelatedContentMock.contents(for: "7").count, 8)
    }

    func test_게시물이_없는_장소는_목록이_비고_더보기가_없다() {
        let state = PlaceDetailFeature.State(
            savedPlace: .fixture(id: RelatedContentMock.emptyPlaceID, bookmarkCount: 1)
        )

        XCTAssertTrue(state.visibleContents.isEmpty)
        XCTAssertFalse(state.canLoadMore)
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
        }
    }

    func test_조회가_실패해도_넘겨받은_값이_남는다() async {
        let saved = SavedPlace.mocks[0]
        let store = TestStore(initialState: PlaceDetailFeature.State(savedPlace: saved)) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.placeClient.placeDetail = { _ in throw PlaceError.network }
        }

        await store.send(.onAppear)
        // 상태가 하나도 안 바뀐다
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
        }
        XCTAssertEqual(store.state.id, originalID)
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
        }

        await store.send(.onAppear)

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
