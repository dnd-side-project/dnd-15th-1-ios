//
//  PlaceImportEndpoint.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Foundation

enum PlaceImportEndpoint: APIEndpoint {
    case start(sourceURL: String)
    case poll(importID: String)
    case confirm(importID: String, candidateIDs: [Int])

    var path: String {
        switch self {
        case .start:
            return "/api/v1/place-imports"
        case let .poll(importID):
            return "/api/v1/place-imports/\(importID)"
        case let .confirm(importID, _):
            return "/api/v1/place-imports/\(importID)/confirm"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .poll:
            return .get
        case .start, .confirm:
            return .post
        }
    }

    var body: Data? {
        let encoder = NetworkJSONCoding.makeEncoder()
        switch self {
        case let .start(sourceURL):
            return try? encoder.encode(PlaceImportDTOMapper.toStartRequest(sourceURL: sourceURL))
        case let .confirm(_, candidateIDs):
            return try? encoder.encode(PlaceImportDTOMapper.toConfirmRequest(candidateIDs: candidateIDs))
        case .poll:
            return nil
        }
    }
}
