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

    var path: String {
        switch self {
        case .savedPlaces:
            return "/api/v1/places"
        case .search:
            return "/api/v1/places/search"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .savedPlaces, .search:
            return .get
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .savedPlaces:
            return []
        case let .search(query, page, size):
            return [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        }
    }
}
