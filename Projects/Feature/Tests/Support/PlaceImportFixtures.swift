import Domain
import Foundation
import SharedUtils

extension ImportCandidate {
    static func fixture(
        id: String,
        name: String = "후보 장소",
        isSaved: Bool = false
    ) -> ImportCandidate {
        ImportCandidate(
            id: id,
            extractedName: name,
            extractedAddressHint: "서울 성동구",
            place: ContentPlace(
                place: Place(
                    placeID: id,
                    kakaoPlaceID: "kakao-\(id)",
                    name: name,
                    category: .cafe,
                    address: "서울특별시 성동구 성수동1가 685",
                    roadAddress: "서울특별시 성동구 서울숲2길 10",
                    coordinate: Coordinate(latitude: 37.5446, longitude: 127.0557),
                    bookmarkCount: nil,
                    thumbnailURLs: []
                ),
                isSaved: isSaved
            )
        )
    }
}

extension PlaceImport {
    static func fixture(
        id: String = "270",
        progress: ImportProgress
    ) -> PlaceImport {
        PlaceImport(
            id: id,
            canonicalURL: URL(string: "https://www.instagram.com/reel/example/"),
            progress: progress,
            content: ImportContent(
                title: "성수동 카페 네 곳",
                caption: nil,
                thumbnailURL: nil,
                author: nil,
                publishedOn: nil
            )
        )
    }
}
