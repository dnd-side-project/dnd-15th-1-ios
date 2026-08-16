//
//  ImportCandidate.swift
//  Dulpick
//
//  Created by 이인호 on 8/16/26.
//

import Foundation

public struct ImportCandidate: Equatable, Identifiable, Sendable {
    public var id: Int { candidateId }
    public let candidateId: Int
    public let verificationStatus: VerificationStatus
    public let extractedName: String
    public let extractedAddressHint: String?
    public let place: ImportPlace?
    public let evidence: String

    public init(
        candidateId: Int,
        verificationStatus: VerificationStatus,
        extractedName: String,
        extractedAddressHint: String?,
        place: ImportPlace?,
        evidence: String
    ) {
        self.candidateId = candidateId
        self.verificationStatus = verificationStatus
        self.extractedName = extractedName
        self.extractedAddressHint = extractedAddressHint
        self.place = place
        self.evidence = evidence
    }
}

public enum VerificationStatus: String, Equatable, Sendable {
    case extracted = "EXTRACTED"
    case verified = "VERIFIED"
    case reviewRequired = "REVIEW_REQUIRED"
}

public struct ImportPlace: Equatable, Sendable {
    public let placeId: Int
    public let kakaoPlaceId: String
    public let name: String
    public let address: String
    public let roadAddress: String
    public let latitude: Double
    public let longitude: Double
    public let category: String
    public let categoryName: String
    public let savedByMe: Bool
    public let thumbnailUrl: String?
    public let imageUrls: [String]

    public init(
        placeId: Int,
        kakaoPlaceId: String,
        name: String,
        address: String,
        roadAddress: String,
        latitude: Double,
        longitude: Double,
        category: String,
        categoryName: String,
        savedByMe: Bool,
        thumbnailUrl: String?,
        imageUrls: [String]
    ) {
        self.placeId = placeId
        self.kakaoPlaceId = kakaoPlaceId
        self.name = name
        self.address = address
        self.roadAddress = roadAddress
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.categoryName = categoryName
        self.savedByMe = savedByMe
        self.thumbnailUrl = thumbnailUrl
        self.imageUrls = imageUrls
    }
}
