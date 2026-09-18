import Domain
import Foundation
import XCTest

@testable import Data

/// 전 `PlaceImportFeature.applyImport` 의 해석표다. 다음 동작을 먼저 보고, 없을 때만 작업 상태를 본다
final class PlaceImportDTOMapperProgressTests: XCTestCase {

    func test_다음_동작이_WAIT면_처리_중이고_다시_물을_초를_옮긴다() {
        let result = PlaceImportDTOMapper.toDomain(
            importDTO(status: "PROCESSING", nextAction: "WAIT", retryAfterSeconds: 3)
        )

        XCTAssertEqual(result.progress, .processing(retryAfterSeconds: 3))
    }

    func test_다음_동작이_SELECT_PLACES면_검토_필요다() {
        let result = PlaceImportDTOMapper.toDomain(
            importDTO(status: "REVIEW_REQUIRED", nextAction: "SELECT_PLACES", candidates: [candidateDTO(id: 1)])
        )

        guard case let .reviewRequired(candidates) = result.progress else {
            return XCTFail("\(result.progress)")
        }
        XCTAssertEqual(candidates.map(\.id), ["1"])
    }

    func test_다음_동작이_COMPLETED면_완료다() {
        let result = PlaceImportDTOMapper.toDomain(
            importDTO(status: "COMPLETED", nextAction: "COMPLETED", candidates: [candidateDTO(id: 2)])
        )

        guard case let .completed(candidates) = result.progress else {
            return XCTFail("\(result.progress)")
        }
        XCTAssertEqual(candidates.map(\.id), ["2"])
    }

    func test_다음_동작이_없고_작업_상태가_완료면_완료다() {
        let progress = PlaceImportDTOMapper.progress(
            status: "COMPLETED", nextAction: "NONE", retryAfterSeconds: nil, candidates: []
        )

        XCTAssertEqual(progress, .completed([]))
    }

    func test_다음_동작이_없고_작업_상태가_검토_필요면_검토_필요다() {
        let progress = PlaceImportDTOMapper.progress(
            status: "REVIEW_REQUIRED", nextAction: "NONE", retryAfterSeconds: nil, candidates: []
        )

        XCTAssertEqual(progress, .reviewRequired([]))
    }

    func test_다음_동작이_없고_작업_상태가_실패면_실패다() {
        let progress = PlaceImportDTOMapper.progress(
            status: "FAILED", nextAction: "NONE", retryAfterSeconds: nil, candidates: []
        )

        XCTAssertEqual(progress, .failed)
    }

    func test_다음_동작이_없고_작업_상태가_받음이나_처리_중이면_처리_중이다() {
        for status in ["RECEIVED", "PROCESSING"] {
            let progress = PlaceImportDTOMapper.progress(
                status: status, nextAction: "NONE", retryAfterSeconds: 1, candidates: []
            )

            XCTAssertEqual(progress, .processing(retryAfterSeconds: 1), status)
        }
    }

    func test_다음_동작이_RETRY면_실패다() {
        let progress = PlaceImportDTOMapper.progress(
            status: "PROCESSING", nextAction: "RETRY", retryAfterSeconds: nil, candidates: []
        )

        XCTAssertEqual(progress, .failed)
    }

    func test_모르는_다음_동작은_실패다() {
        let progress = PlaceImportDTOMapper.progress(
            status: "COMPLETED", nextAction: "SOMETHING", retryAfterSeconds: nil, candidates: []
        )

        XCTAssertEqual(progress, .failed)
    }

    func test_다음_동작이_없고_모르는_작업_상태는_실패다() {
        let progress = PlaceImportDTOMapper.progress(
            status: "SOMETHING", nextAction: "NONE", retryAfterSeconds: nil, candidates: []
        )

        XCTAssertEqual(progress, .failed)
    }
}

final class PlaceImportDTOMapperTests: XCTestCase {

    func test_번호는_문자열이고_원본_링크는_URL이다() {
        let result = PlaceImportDTOMapper.toDomain(importDTO())

        XCTAssertEqual(result.id, "270")
        XCTAssertEqual(result.canonicalURL?.absoluteString, "https://www.instagram.com/reel/example/")
        XCTAssertEqual(result.content.thumbnailURL?.absoluteString, "https://example.com/c.jpg")
    }

    // 사용자 보정(2026-09-18): 원본 링크는 옵셔널이다. 못 읽어도 가져오기는 실패가 아니다
    func test_원본_링크를_못_읽으면_nil이고_가져오기는_계속된다() {
        let result = PlaceImportDTOMapper.toDomain(
            importDTO(canonicalUrl: "", candidates: [candidateDTO(id: 2)])
        )

        XCTAssertNil(result.canonicalURL)
        guard case let .completed(candidates) = result.progress else {
            return XCTFail("\(result.progress)")
        }
        XCTAssertEqual(candidates.map(\.id), ["2"])
    }

    func test_게시일을_읽는다() {
        let result = PlaceImportDTOMapper.toDomain(importDTO(publishedOn: "2026-08-16"))

        // 2026-08-16 00:00 Asia/Seoul
        XCTAssertEqual(result.content.publishedOn, Date(timeIntervalSince1970: 1_786_806_000))
    }

    func test_게시일을_못_읽으면_nil이고_가져오기는_실패가_아니다() {
        let result = PlaceImportDTOMapper.toDomain(importDTO(publishedOn: "8월 16일"))

        XCTAssertNil(result.content.publishedOn)
    }

    func test_확인된_장소는_게시글_속_장소로_옮긴다() throws {
        let result = PlaceImportDTOMapper.toDomain(
            importDTO(nextAction: "SELECT_PLACES", candidates: [candidateDTO(id: 1)])
        )
        guard case let .reviewRequired(candidates) = result.progress else {
            return XCTFail("\(result.progress)")
        }
        let place = try XCTUnwrap(candidates.first?.place)

        XCTAssertEqual(place.place.placeID, "11")
        XCTAssertEqual(place.place.kakaoPlaceID, "kakao-1")
        XCTAssertEqual(place.place.category, .cafe)
        XCTAssertEqual(place.place.coordinate.latitude, 37.5, accuracy: 0.0001)
        XCTAssertNil(place.place.roadAddress)
        XCTAssertNil(place.place.bookmarkCount)
        XCTAssertTrue(place.isSaved)
        XCTAssertEqual(place.place.thumbnailURLs.map(\.absoluteString), [
            "https://example.com/t.jpg",
            "https://example.com/a.jpg",
        ])
    }

    // 서버가 도로명 없음을 "" 로 주는 응답이 있다. nil 과 같게 읽혀야 CandidateRow 의 주소 힌트 대체가 산다
    func test_확인된_장소_도로명_빈_문자열은_nil이다() throws {
        let result = PlaceImportDTOMapper.toDomain(
            importDTO(nextAction: "SELECT_PLACES", candidates: [candidateDTO(id: 1, roadAddress: "")])
        )
        guard case let .reviewRequired(candidates) = result.progress else {
            return XCTFail("\(result.progress)")
        }
        let place = try XCTUnwrap(candidates.first?.place)

        XCTAssertNil(place.place.roadAddress)
    }

    func test_확인_못_한_후보는_장소가_없다() {
        let result = PlaceImportDTOMapper.toDomain(
            importDTO(nextAction: "SELECT_PLACES", candidates: [candidateDTO(id: 1, hasPlace: false)])
        )
        guard case let .reviewRequired(candidates) = result.progress else {
            return XCTFail("\(result.progress)")
        }

        XCTAssertNil(candidates.first?.place)
        XCTAssertEqual(candidates.first?.extractedName, "후보 1")
    }
}

private func importDTO(
    status: String = "COMPLETED",
    nextAction: String = "COMPLETED",
    retryAfterSeconds: Int? = nil,
    canonicalUrl: String = "https://www.instagram.com/reel/example/",
    publishedOn: String? = nil,
    candidates: [ImportCandidateDTO] = []
) -> PlaceImportResponseDTO {
    PlaceImportResponseDTO(
        importId: 270,
        contentId: nil,
        canonicalUrl: canonicalUrl,
        sourceType: "INSTAGRAM_REEL",
        status: status,
        nextAction: nextAction,
        retryAfterSeconds: retryAfterSeconds,
        failure: nil,
        content: ImportContentDTO(
            title: "제목",
            caption: nil,
            thumbnailUrl: "https://example.com/c.jpg",
            author: nil,
            publishedOn: publishedOn
        ),
        candidates: candidates
    )
}

private func candidateDTO(id: Int, hasPlace: Bool = true, roadAddress: String? = nil) -> ImportCandidateDTO {
    ImportCandidateDTO(
        candidateId: id,
        verificationStatus: "VERIFIED",
        extractedName: "후보 \(id)",
        extractedAddressHint: "서울 성동구",
        place: hasPlace ? placeDTO(id: id, roadAddress: roadAddress) : nil,
        evidence: nil
    )
}

private func placeDTO(id: Int, roadAddress: String? = nil) -> ImportPlaceDTO {
    ImportPlaceDTO(
        placeId: id + 10,
        kakaoPlaceId: "kakao-\(id)",
        name: "장소 \(id)",
        address: "서울 성동구 성수동",
        roadAddress: roadAddress,
        latitude: 37.5,
        longitude: 127.0,
        category: "음식점 > 카페",
        categoryName: "카페",
        savedByMe: true,
        thumbnailUrl: "https://example.com/t.jpg",
        imageUrls: ["https://example.com/a.jpg"]
    )
}
