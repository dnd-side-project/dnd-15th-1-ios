import Domain
import Foundation

extension ImportCandidate {
    static func fixture(
        candidateId: Int,
        name: String = "후보 장소",
        savedByMe: Bool = false
    ) -> ImportCandidate {
        ImportCandidate(
            candidateId: candidateId,
            verificationStatus: .verified,
            extractedName: name,
            extractedAddressHint: "서울 성동구",
            place: ImportPlace(
                placeId: candidateId,
                kakaoPlaceId: "kakao-\(candidateId)",
                name: name,
                address: "서울특별시 성동구 성수동1가 685",
                roadAddress: "서울특별시 성동구 서울숲2길 10",
                latitude: 37.5446,
                longitude: 127.0557,
                category: "음식점 > 카페",
                categoryName: "카페",
                savedByMe: savedByMe,
                thumbnailUrl: nil,
                imageUrls: []
            ),
            evidence: nil
        )
    }
}

extension PlaceImport {
    static func fixture(
        importId: Int = 270,
        status: ImportStatus,
        nextAction: ImportNextAction,
        candidates: [ImportCandidate] = [],
        retryAfterSeconds: Int? = nil
    ) -> PlaceImport {
        PlaceImport(
            importId: importId,
            contentId: nil,
            canonicalUrl: "https://www.instagram.com/reel/example/",
            sourceType: .instagramReel,
            status: status,
            nextAction: nextAction,
            retryAfterSeconds: retryAfterSeconds,
            failure: nil,
            content: ImportContent(
                title: "성수동 카페 네 곳",
                caption: nil,
                thumbnailUrl: nil,
                author: nil,
                publishedOn: nil
            ),
            candidates: candidates
        )
    }
}
