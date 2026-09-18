//
//  PlaceImportDTOMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation
import SharedUtils

enum PlaceImportDTOMapper {
    static func toStartRequest(sourceURL: String) -> PlaceImportStartRequestDTO {
        PlaceImportStartRequestDTO(sourceUrl: sourceURL)
    }

    static func toConfirmRequest(candidateIDs: [Int]) -> PlaceImportConfirmRequestDTO {
        PlaceImportConfirmRequestDTO(
            selections: candidateIDs.map {
                PlaceImportConfirmRequestDTO.SelectionDTO(candidateId: $0, alias: nil)
            }
        )
    }

    static func toDomain(_ dto: PlaceImportResponseDTO) -> PlaceImport {
        PlaceImport(
            id: String(dto.importId),
            // 원본 링크를 못 읽어도 가져오기는 계속된다. 원본 열기만 동작하지 않는다
            canonicalURL: URL(string: dto.canonicalUrl),
            progress: progress(
                status: dto.status,
                nextAction: dto.nextAction,
                retryAfterSeconds: dto.retryAfterSeconds,
                candidates: dto.candidates.map(toCandidate)
            ),
            content: toContent(dto.content)
        )
    }

    /// 서버의 작업 상태와 다음 동작을 진행 상태 넷으로 읽는다.
    /// 두 값의 조합 명세가 없어 화면이 쓰던 해석을 그대로 옮겼다.
    /// 다음 동작을 먼저 보고, 다음 동작이 없을 때만 작업 상태를 본다. 모르는 값은 실패다
    static func progress(
        status: String,
        nextAction: String,
        retryAfterSeconds: Int?,
        candidates: [ImportCandidate]
    ) -> ImportProgress {
        switch nextAction {
        case "WAIT":
            return .processing(retryAfterSeconds: retryAfterSeconds)
        case "SELECT_PLACES":
            return .reviewRequired(candidates)
        case "COMPLETED":
            return .completed(candidates)
        case "NONE":
            switch status {
            case "COMPLETED":
                return .completed(candidates)
            case "REVIEW_REQUIRED":
                return .reviewRequired(candidates)
            case "RECEIVED", "PROCESSING":
                return .processing(retryAfterSeconds: retryAfterSeconds)
            default:
                return .failed
            }
        default:
            // RETRY 와 모르는 값
            return .failed
        }
    }

    private static func toContent(_ dto: ImportContentDTO) -> ImportContent {
        ImportContent(
            title: dto.title,
            caption: dto.caption,
            thumbnailURL: dto.thumbnailUrl.flatMap(URL.init(string:)),
            author: dto.author.map { ImportAuthor(displayName: $0.displayName, username: $0.username) },
            // 게시일을 못 읽어도 가져오기는 실패가 아니다
            publishedOn: dto.publishedOn.flatMap(CourseDateFormat.date(from:))
        )
    }

    private static func toCandidate(_ dto: ImportCandidateDTO) -> ImportCandidate {
        ImportCandidate(
            id: String(dto.candidateId),
            extractedName: dto.extractedName,
            extractedAddressHint: dto.extractedAddressHint,
            place: dto.place.map(toContentPlace)
        )
    }

    private static func toContentPlace(_ dto: ImportPlaceDTO) -> ContentPlace {
        ContentPlace(
            place: Place(
                placeID: String(dto.placeId),
                kakaoPlaceID: dto.kakaoPlaceId,
                name: dto.name,
                category: PlaceDTOMapper.category(code: nil, name: dto.categoryName),
                address: dto.address,
                roadAddress: PlaceDTOMapper.roadAddress(dto.roadAddress),
                coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
                // 가져오기 응답에는 저장 수가 없다
                bookmarkCount: nil,
                thumbnailURLs: PlaceDTOMapper.photoURLs(
                    thumbnailURL: dto.thumbnailUrl,
                    imageURLs: dto.imageUrls
                )
            ),
            isSaved: dto.savedByMe
        )
    }
}
