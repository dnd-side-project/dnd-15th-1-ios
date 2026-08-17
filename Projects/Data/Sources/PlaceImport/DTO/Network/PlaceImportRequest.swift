//
//  PlaceImportRequest.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Foundation

struct PlaceImportStartRequestDTO: Encodable, Sendable {
    let sourceUrl: String
}

struct PlaceImportConfirmRequestDTO: Encodable, Sendable {
    let selections: [SelectionDTO]

    struct SelectionDTO: Encodable, Sendable {
        let candidateId: Int
        let alias: String?
    }
}
