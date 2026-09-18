import Domain
import Foundation
import SharedUtils

extension Place {
    static func fixture(
        id: String,
        name: String = "장소명",
        category: PlaceCategory = .food,
        latitude: Double = 37.3128,
        longitude: Double = 126.9040,
        bookmarkCount: Int? = 0
    ) -> Place {
        Place(
            placeID: id,
            kakaoPlaceID: nil,
            name: name,
            category: category,
            address: "경기도 안산시 모모로 145길",
            roadAddress: "경기도 안산시 모모로 145",
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            bookmarkCount: bookmarkCount,
            thumbnailURLs: []
        )
    }

    /// 같은 장소에 저장 수만 바꾼 값. 상세 응답이 주는 저장 수를 흉내 낸다
    func withBookmarkCount(_ count: Int?) -> Place {
        Place(
            placeID: placeID,
            kakaoPlaceID: kakaoPlaceID,
            name: name,
            category: category,
            address: address,
            roadAddress: roadAddress,
            coordinate: coordinate,
            bookmarkCount: count,
            thumbnailURLs: thumbnailURLs
        )
    }
}

extension SavedPlace {
    static func fixture(
        id: String,
        latitude: Double = 37.3,
        longitude: Double = 126.9,
        category: PlaceCategory = .cafe,
        ownership: PlaceOwnership = .mine,
        alias: String? = nil,
        name: String? = nil,
        bookmarkCount: Int? = 0
    ) -> SavedPlace {
        SavedPlace(
            place: Place(
                placeID: id,
                kakaoPlaceID: "kakao-\(id)",
                name: name ?? "장소 \(id)",
                category: category,
                address: "경기도 안산시 상록구 건건동 \(id)",
                roadAddress: "경기도 안산시 상록구 건건로 \(id)",
                coordinate: Coordinate(latitude: latitude, longitude: longitude),
                bookmarkCount: bookmarkCount,
                thumbnailURLs: []
            ),
            ownership: ownership,
            alias: alias,
            memo: nil,
            savedAt: Date(timeIntervalSince1970: 1_786_000_000)
        )
    }
}

extension SavedPlace {
    /// 코스 장소 고르기 화면의 후보. 코스 후보 응답처럼 카카오 번호·저장 수·저장 시각이 없다
    static func candidateFixture(
        id: String,
        latitude: Double = 37.31,
        longitude: Double = 126.90,
        category: PlaceCategory = .food,
        ownership: PlaceOwnership = .together,
        roadAddress: String? = "경기도 안산시 모모로 145"
    ) -> SavedPlace {
        SavedPlace(
            place: Place(
                placeID: id,
                kakaoPlaceID: nil,
                name: "장소명",
                category: category,
                address: "경기도 안산시 모모로 145길",
                roadAddress: roadAddress,
                coordinate: Coordinate(latitude: latitude, longitude: longitude),
                bookmarkCount: nil,
                thumbnailURLs: []
            ),
            ownership: ownership,
            alias: nil,
            memo: nil,
            savedAt: nil
        )
    }
}

extension ContentPlace {
    static func fixture(
        placeID: String,
        kakaoPlaceID: String? = nil,
        name: String = "장소명",
        category: PlaceCategory = .food,
        isSaved: Bool = false,
        latitude: Double = 37.5,
        longitude: Double = 127.0
    ) -> ContentPlace {
        ContentPlace(
            place: Place(
                placeID: placeID,
                kakaoPlaceID: kakaoPlaceID,
                name: name,
                category: category,
                address: "",
                roadAddress: nil,
                coordinate: Coordinate(latitude: latitude, longitude: longitude),
                bookmarkCount: nil,
                thumbnailURLs: []
            ),
            isSaved: isSaved
        )
    }
}

enum PlaceFixtures {
    static let savedPlaces: [SavedPlace] = [
        .fixture(id: "1", latitude: 37.3128, longitude: 126.9040, category: .cafe),
        .fixture(id: "2", latitude: 37.3141, longitude: 126.9068, category: .food),
        .fixture(id: "3", latitude: 37.3200, longitude: 126.9100, category: .tourism),
    ]

    static let coursePlaceCandidates: [SavedPlace] = [
        .candidateFixture(id: "a", latitude: 37.31, longitude: 126.90, category: .food),
        .candidateFixture(id: "b", latitude: 37.32, longitude: 126.91, category: .cafe),
        .candidateFixture(id: "c", latitude: 37.33, longitude: 126.92, category: .tourism),
    ]
}
