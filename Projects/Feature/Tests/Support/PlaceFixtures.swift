import Domain
import Foundation
import SharedUtils

extension Place {
    static func fixture(
        id: String,
        name: String = "장소명",
        category: PlaceCategory = .food,
        latitude: Double = 37.3128,
        longitude: Double = 126.9040
    ) -> Place {
        Place(
            id: id,
            kakaoPlaceID: nil,
            name: name,
            category: category,
            address: "경기도 안산시 모모로 145길",
            roadAddress: "경기도 안산시 모모로 145",
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            bookmarkCount: 0,
            thumbnailURLs: []
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
        bookmarkCount: Int = 0
    ) -> SavedPlace {
        SavedPlace(
            place: Place(
                id: id,
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

extension CoursePlaceCandidate {
    static func fixture(
        id: String,
        latitude: Double = 37.31,
        longitude: Double = 126.90,
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

enum PlaceFixtures {
    static let savedPlaces: [SavedPlace] = [
        .fixture(id: "1", latitude: 37.3128, longitude: 126.9040, category: .cafe),
        .fixture(id: "2", latitude: 37.3141, longitude: 126.9068, category: .food),
        .fixture(id: "3", latitude: 37.3200, longitude: 126.9100, category: .tourism),
    ]

    static let coursePlaceCandidates: [CoursePlaceCandidate] = [
        .fixture(id: "a", latitude: 37.31, longitude: 126.90, category: .food),
        .fixture(id: "b", latitude: 37.32, longitude: 126.91, category: .cafe),
        .fixture(id: "c", latitude: 37.33, longitude: 126.92, category: .tourism),
    ]
}
