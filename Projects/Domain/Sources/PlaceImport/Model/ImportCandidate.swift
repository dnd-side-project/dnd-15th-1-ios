//
//  ImportCandidate.swift
//  Dulpick
//
//  Created by 이인호 on 8/16/26.
//

import Foundation

public struct ImportCandidate: Equatable, Identifiable, Sendable {
    public let id: String
    public let extractedName: String
    public let extractedAddressHint: String?
    /// 둘픽이 확인한 장소. 확인하지 못했으면 nil
    public let place: ContentPlace?

    public init(
        id: String,
        extractedName: String,
        extractedAddressHint: String?,
        place: ContentPlace?
    ) {
        self.id = id
        self.extractedName = extractedName
        self.extractedAddressHint = extractedAddressHint
        self.place = place
    }
}
