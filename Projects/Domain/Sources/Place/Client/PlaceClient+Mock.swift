//
//  PlaceClient+Mock.swift
//  Dulpick
//
//  임시 mock 데이터
//

import Foundation
import ThirdParty

public extension PlaceClient {
    static let mock = PlaceClient(
        savedPlaces: { SavedPlace.mocks },
        searchPlaces: { query in
            let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
            // 빈 검색어는 빈 결과다. 화면이 이미 빈 질의를 막고 있고,
            // 여기서 전체를 돌려주면 "검색 안 해도 결과가 뜬다" 는 착각을 만든다
            guard !keyword.isEmpty else { return [] }

            return Place.mocks.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
        },
        savePlace: { kakaoPlaceID, query, alias, memo in
            let place = Place.mocks.first { $0.kakaoPlaceID == kakaoPlaceID }
                ?? Place.mocks.first { $0.name.contains(query) }
                ?? Place.mocks[0]

            return SavedPlace(
                place: place,
                ownership: .mine,
                alias: alias,
                memo: memo,
                savedAt: Date(timeIntervalSince1970: 1_786_000_000)
            )
        }
    )
}

public extension Place {
    static let mocks: [Place] = [
        Place(
            id: "1",
            kakaoPlaceID: "26338954",
            name: "까치화방 카페 강남점",
            category: .cafe,
            address: "서울특별시 강남구 역삼동 736-15",
            roadAddress: "서울특별시 강남구 테헤란로 152",
            coordinate: Coordinate(latitude: 37.5006, longitude: 127.0366),
            bookmarkCount: 12,
            thumbnailURLs: []
        ),
        Place(
            id: "2",
            kakaoPlaceID: "26338955",
            name: "까치화방 카페 성수역",
            category: .cafe,
            address: "서울특별시 성동구 성수동2가 315-1",
            roadAddress: "서울특별시 성동구 아차산로 100",
            coordinate: Coordinate(latitude: 37.5446, longitude: 127.0559),
            bookmarkCount: 12,
            thumbnailURLs: MockThumbnailURL.list(4, seed: 50)
        ),
        Place(
            id: "3",
            kakaoPlaceID: "10000003",
            name: "반월역 앞 국수집",
            category: .food,
            address: "경기도 안산시 상록구 건건동 812-3",
            roadAddress: "경기도 안산시 상록구 건건로 145",
            coordinate: Coordinate(latitude: 37.3128, longitude: 126.9040),
            bookmarkCount: 124,
            thumbnailURLs: MockThumbnailURL.list(3, seed: 60)
        ),
        Place(
            id: "4",
            kakaoPlaceID: "10000004",
            name: "건건동 로스터리",
            category: .cafe,
            address: "경기도 안산시 상록구 건건동 795-12",
            roadAddress: "경기도 안산시 상록구 반월로 32",
            coordinate: Coordinate(latitude: 37.3141, longitude: 126.9068),
            bookmarkCount: 87,
            thumbnailURLs: MockThumbnailURL.list(3, seed: 70)
        ),
        Place(
            id: "5",
            kakaoPlaceID: "10000005",
            name: "안산반월도서관",
            category: .tourism,
            address: "경기도 안산시 상록구 건건동 621-4",
            roadAddress: "경기도 안산시 상록구 건건로 78",
            coordinate: Coordinate(latitude: 37.3101, longitude: 126.9018),
            bookmarkCount: 41,
            thumbnailURLs: MockThumbnailURL.list(2, seed: 80)
        ),
        Place(
            id: "6",
            kakaoPlaceID: "10000006",
            name: "치맛산 등산로 입구",
            category: .activity,
            address: "경기도 안산시 상록구 건건동 산 47",
            roadAddress: "경기도 안산시 상록구 건건로 12",
            coordinate: Coordinate(latitude: 37.3116, longitude: 126.8963),
            bookmarkCount: 63,
            thumbnailURLs: MockThumbnailURL.list(2, seed: 90)
        ),
        Place(
            id: "7",
            kakaoPlaceID: "10000007",
            name: "창촌초 앞 분식",
            category: .food,
            address: "경기도 안산시 상록구 건건동 903-8",
            roadAddress: "경기도 안산시 상록구 삼천리로 21",
            coordinate: Coordinate(latitude: 37.3084, longitude: 126.9061),
            bookmarkCount: 35,
            thumbnailURLs: MockThumbnailURL.list(2, seed: 100)
        ),
        Place(
            id: "8",
            kakaoPlaceID: "10000008",
            name: "건건동 생활마트",
            category: .shopping,
            address: "경기도 안산시 상록구 건건동 770-1",
            roadAddress: "경기도 안산시 상록구 반월로 61",
            coordinate: Coordinate(latitude: 37.3147, longitude: 126.9025),
            bookmarkCount: 18,
            thumbnailURLs: MockThumbnailURL.list(2, seed: 110)
        ),
        Place(
            id: "9",
            kakaoPlaceID: "10000009",
            name: "e편한세상 앞 베이커리",
            category: .cafe,
            address: "경기도 안산시 상록구 건건동 688-9",
            roadAddress: "경기도 안산시 상록구 건건로 210",
            coordinate: Coordinate(latitude: 37.3136, longitude: 126.9081),
            bookmarkCount: 52,
            thumbnailURLs: MockThumbnailURL.list(3, seed: 120)
        ),
    ]
}

public extension SavedPlace {
    /// 안산시 상록구 건건동, 반월역 일대. 지도 탭 기본 카메라와 같은 자리다
    static let mocks: [SavedPlace] = [
        mock(placeID: "3", ownership: .together, savedAtOffset: 0),
        mock(placeID: "4", ownership: .mine, savedAtOffset: 1),
        mock(placeID: "5", ownership: .together, savedAtOffset: 2),
        mock(placeID: "6", ownership: .partner, savedAtOffset: 3),
        mock(placeID: "7", ownership: .mine, savedAtOffset: 4),
        mock(placeID: "8", ownership: .partner, savedAtOffset: 5),
        mock(placeID: "9", ownership: .together, savedAtOffset: 6),
    ]

    private static func mock(
        placeID: String,
        ownership: PlaceOwnership,
        savedAtOffset: Int
    ) -> SavedPlace {
        let place = Place.mocks.first { $0.id == placeID } ?? Place.mocks[0]

        return SavedPlace(
            place: place,
            ownership: ownership,
            alias: nil,
            memo: nil,
            savedAt: Date(timeIntervalSince1970: 1_786_000_000 - Double(savedAtOffset) * 86_400)
        )
    }
}
