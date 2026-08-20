import Domain
import Foundation

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
        latitude: Double,
        longitude: Double,
        category: PlaceCategory = .cafe,
        ownership: PlaceOwnership = .mine
    ) -> SavedPlace {
        SavedPlace(
            place: Place(
                id: id,
                kakaoPlaceID: "kakao-\(id)",
                name: "장소 \(id)",
                category: category,
                address: "경기도 안산시 상록구 건건동 \(id)",
                roadAddress: "경기도 안산시 상록구 건건로 \(id)",
                coordinate: Coordinate(latitude: latitude, longitude: longitude),
                bookmarkCount: 0,
                thumbnailURLs: []
            ),
            ownership: ownership,
            alias: nil,
            memo: nil,
            savedAt: Date(timeIntervalSince1970: 1_786_000_000)
        )
    }
}
