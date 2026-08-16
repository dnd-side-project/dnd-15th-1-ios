//
//  PlaceImportMock.swift
//  Dulpick
//
//  Created by 이인호 on 8/16/26.
//
//  임시 mock 데이터
//

import Foundation

public extension PlaceImport {
    static let mock = PlaceImport(
        importId: 4,
        contentId: 3,
        canonicalUrl: "https://www.instagram.com/reel/DCOz7MlslHs",
        sourceType: .instagramReel,
        status: .reviewRequired,
        nextAction: .selectPlaces,
        retryAfterSeconds: nil,
        failure: nil,
        content: ImportContent(
            title: "한강 데이트 코스 베스트 5",
            caption: nil,
            thumbnailUrl: nil,
            author: ImportAuthor(displayName: "유니져니", username: "yuni._.journey"),
            publishedOn: "2024-11-11"
        ),
        candidates: ImportCandidate.mocks
    )

    static let failedMock = PlaceImport(
        importId: 3,
        contentId: 2,
        canonicalUrl: "https://www.instagram.com/p/DVn5M4Ij-oK",
        sourceType: .instagramPost,
        status: .failed,
        nextAction: .retry,
        retryAfterSeconds: 300,
        failure: ImportFailure(code: "PLACE_METADATA_UNAVAILABLE", retryable: true),
        content: ImportContent(
            title: "서촌을 뿌사보자",
            caption: nil,
            thumbnailUrl: nil,
            author: nil,
            publishedOn: nil
        ),
        candidates: []
    )
}

public extension ImportCandidate {
    static let mocks: [ImportCandidate] = [
        mock(id: 13, name: "보안여관", categoryName: "놀거리"),
        mock(id: 14, name: "보안책방", categoryName: "놀거리"),
        mock(id: 15, name: "카멜커피 서촌점", categoryName: "카페"),
        mock(id: 16, name: "경복궁", categoryName: "관광"),
        mock(id: 17, name: "스태픽스", categoryName: "카페"),
        mock(id: 18, name: "오버트서울", categoryName: "카페"),
        mock(id: 19, name: "잘빠진메밀 서촌 본점", categoryName: "카페"),
    ]

    private static func mock(id: Int, name: String, categoryName: String) -> ImportCandidate {
        ImportCandidate(
            candidateId: id,
            verificationStatus: .verified,
            extractedName: name,
            extractedAddressHint: "서촌",
            place: ImportPlace(
                placeId: id,
                kakaoPlaceId: "\(id)",
                name: name,
                address: "서울 종로구 통의동 2-1",
                roadAddress: "서울 종로구 효자로 33",
                latitude: 37.5791083,
                longitude: 126.9736268,
                category: "음식점 > 카페",
                categoryName: categoryName,
                savedByMe: false,
                thumbnailUrl: nil,
                imageUrls: []
            ),
            evidence: name
        )
    }
}
