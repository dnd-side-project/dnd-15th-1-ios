//
//  PlaceImport.swift
//  Dulpick
//
//  Created by 이인호 on 8/16/26.
//

import Foundation

public struct PlaceImport: Equatable, Identifiable, Sendable {
    public var id: Int { importId }
    public let importId: Int
    public let contentId: Int?
    public let canonicalUrl: String
    public let sourceType: ImportSourceType
    public let status: ImportStatus
    public let nextAction: ImportNextAction
    public let retryAfterSeconds: Int?
    public let failure: ImportFailure?
    public let content: ImportContent
    public let candidates: [ImportCandidate]

    public init(
        importId: Int,
        contentId: Int?,
        canonicalUrl: String,
        sourceType: ImportSourceType,
        status: ImportStatus,
        nextAction: ImportNextAction,
        retryAfterSeconds: Int?,
        failure: ImportFailure?,
        content: ImportContent,
        candidates: [ImportCandidate]
    ) {
        self.importId = importId
        self.contentId = contentId
        self.canonicalUrl = canonicalUrl
        self.sourceType = sourceType
        self.status = status
        self.nextAction = nextAction
        self.retryAfterSeconds = retryAfterSeconds
        self.failure = failure
        self.content = content
        self.candidates = candidates
    }
}

public enum ImportStatus: String, Equatable, Sendable {
    case received = "RECEIVED"
    case processing = "PROCESSING"
    case reviewRequired = "REVIEW_REQUIRED"
    case failed = "FAILED"
}

public enum ImportNextAction: String, Equatable, Sendable {
    case wait = "WAIT"
    case selectPlaces = "SELECT_PLACES"
    case retry = "RETRY"
}

public enum ImportSourceType: String, Equatable, Sendable {
    case instagramReel = "INSTAGRAM_REEL"
    case instagramPost = "INSTAGRAM_POST"
}

public struct ImportFailure: Equatable, Sendable {
    public let code: String
    public let retryable: Bool

    public init(code: String, retryable: Bool) {
        self.code = code
        self.retryable = retryable
    }
}
