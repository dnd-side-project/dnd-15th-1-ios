//
//  PlaceImportEndpoint.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Foundation

enum PlaceImportEndpoint: APIEndpoint {
    case start(sourceUrl: String)
    case poll(importId: Int)
    case confirm(importId: Int, candidateIDs: [Int])

    var path: String {
        switch self {
        case .start:
            return "/api/v1/place-imports"
        case let .poll(importId):
            return "/api/v1/place-imports/\(importId)"
        case let .confirm(importId, _):
            return "/api/v1/place-imports/\(importId)/confirm"
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
        case let .start(sourceUrl):
            return try? encoder.encode(PlaceImportDTOMapper.toStartRequest(sourceUrl: sourceUrl))
        case let .confirm(_, candidateIDs):
            return try? encoder.encode(PlaceImportDTOMapper.toConfirmRequest(candidateIDs: candidateIDs))
        case .poll:
            return nil
        }
    }
}
