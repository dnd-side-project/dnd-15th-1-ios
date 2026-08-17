//
//  PlaceImportDTOMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation

enum PlaceImportDTOMapper {
    static func toStartRequest(sourceUrl: String) -> PlaceImportStartRequestDTO {
        PlaceImportStartRequestDTO(sourceUrl: sourceUrl)
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
            importId: dto.importId,
            contentId: dto.contentId,
            canonicalUrl: dto.canonicalUrl,
            sourceType: ImportSourceType(rawValue: dto.sourceType) ?? .instagramPost,
            status: ImportStatus(rawValue: dto.status) ?? .failed,
            nextAction: ImportNextAction(rawValue: dto.nextAction) ?? .retry,
            retryAfterSeconds: dto.retryAfterSeconds,
            failure: dto.failure.map { ImportFailure(code: $0.code, retryable: $0.retryable) },
            content: toDomain(dto.content),
            candidates: dto.candidates.map(toDomain)
        )
    }

    private static func toDomain(_ dto: ImportContentDTO) -> ImportContent {
        ImportContent(
            title: dto.title,
            caption: dto.caption,
            thumbnailUrl: dto.thumbnailUrl,
            author: dto.author.map { ImportAuthor(displayName: $0.displayName, username: $0.username) },
            publishedOn: dto.publishedOn
        )
    }

    private static func toDomain(_ dto: ImportCandidateDTO) -> ImportCandidate {
        ImportCandidate(
            candidateId: dto.candidateId,
            verificationStatus: VerificationStatus(rawValue: dto.verificationStatus) ?? .extracted,
            extractedName: dto.extractedName,
            extractedAddressHint: dto.extractedAddressHint,
            place: dto.place.map(toDomain),
            evidence: dto.evidence
        )
    }

    private static func toDomain(_ dto: ImportPlaceDTO) -> ImportPlace {
        ImportPlace(
            placeId: dto.placeId,
            kakaoPlaceId: dto.kakaoPlaceId,
            name: dto.name,
            address: dto.address,
            roadAddress: dto.roadAddress,
            latitude: dto.latitude,
            longitude: dto.longitude,
            category: dto.category,
            categoryName: dto.categoryName,
            savedByMe: dto.savedByMe,
            thumbnailUrl: dto.thumbnailUrl,
            imageUrls: dto.imageUrls
        )
    }
}
