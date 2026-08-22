//
//  PlaceEndpoint.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Foundation

enum PlaceEndpoint: APIEndpoint {
    case savedPlaces
    case search(query: String, page: Int, size: Int)
    case save(kakaoPlaceID: String, query: String, alias: String?)
    case remove(placeID: String)

    var path: String {
        switch self {
        case .savedPlaces, .save:
            return "/api/v1/places"
        case .search:
            return "/api/v1/places/search"
        case let .remove(placeID):
            return "/api/v1/places/\(placeID)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .savedPlaces, .search:
            return .get
        case .save:
            return .post
        case .remove:
            return .delete
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .savedPlaces, .save, .remove:
            return []
        case let .search(query, page, size):
            return [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        }
    }

    var body: Data? {
        switch self {
        case let .save(kakaoPlaceID, query, alias):
            let encoder = NetworkJSONCoding.makeEncoder()
            return try? encoder.encode(
                PlaceSaveRequestDTO(kakaoPlaceId: kakaoPlaceID, query: query, alias: alias)
            )
        case .savedPlaces, .search, .remove:
            return nil
        }
    }
}
