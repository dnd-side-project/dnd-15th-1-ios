//
//  PlaceImportResponse.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Foundation

struct PlaceImportResponseDTO: Decodable, Sendable {
    let importId: Int
    let contentId: Int?
    let canonicalUrl: String
    let sourceType: String
    let status: String
    let nextAction: String
    let retryAfterSeconds: Int?
    let failure: ImportFailureDTO?
    let content: ImportContentDTO
    let candidates: [ImportCandidateDTO]
}

struct ImportFailureDTO: Decodable, Sendable {
    let code: String
    let retryable: Bool
}

struct ImportContentDTO: Decodable, Sendable {
    let title: String?
    let caption: String?
    let thumbnailUrl: String?
    let author: ImportAuthorDTO?
    let publishedOn: String?
}

struct ImportAuthorDTO: Decodable, Sendable {
    let displayName: String
    let username: String
}

struct ImportCandidateDTO: Decodable, Sendable {
    let candidateId: Int
    let verificationStatus: String
    let extractedName: String
    let extractedAddressHint: String?
    let place: ImportPlaceDTO?
    let evidence: String?
}

struct ImportPlaceDTO: Decodable, Sendable {
    let placeId: Int
    let kakaoPlaceId: String
    let name: String
    let address: String
    let roadAddress: String
    let latitude: Double
    let longitude: Double
    let category: String
    let categoryName: String
    let savedByMe: Bool
    let thumbnailUrl: String?
    let imageUrls: [String]
}
