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
        let state = PlaceDetailFeature.State(place: place)

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
            $0.isBookmarked = false
            $0.bookmarkCount = 123
        }
        await store.receive(\.delegate.bookmarkToggled)

        await store.send(.bookmarkTapped) {
            $0.isBookmarked = true
            $0.bookmarkCount = 124
        }
        await store.receive(\.delegate.bookmarkToggled)
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

    func test_지도버튼과_게시물과_닫기는_상위로_올린다() async {
        let store = TestStore(
            initialState: PlaceDetailFeature.State(savedPlace: .fixture(id: "7", bookmarkCount: 1))
        ) {
            PlaceDetailFeature()
        }

        await store.send(.mapButtonTapped)
        await store.receive(\.delegate.mapRequested)

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
}
