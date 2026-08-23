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
    case detail(placeID: Int)
    case kakaoDetail(kakaoPlaceID: String, query: String)
    case updateAlias(placeID: Int, alias: String?)

    var path: String {
        switch self {
        case .savedPlaces, .save:
            return "/api/v1/places"
        case .search:
            return "/api/v1/places/search"
        case let .remove(placeID):
            return "/api/v1/places/\(placeID)"
        case let .detail(placeID):
            return "/api/v1/places/\(placeID)"
        case let .kakaoDetail(kakaoPlaceID, _):
            return "/api/v1/places/kakao/\(kakaoPlaceID)"
        case let .updateAlias(placeID, _):
            return "/api/v1/places/\(placeID)/alias"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .savedPlaces, .search, .detail, .kakaoDetail:
            return .get
        case .save:
            return .post
        case .remove:
            return .delete
        case .updateAlias:
            return .patch
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .savedPlaces, .save, .remove, .detail, .updateAlias:
            return []
        case let .search(query, page, size):
            return [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        case let .kakaoDetail(_, query):
            // query 는 필수다. 빠지면 서버가 400 이 아니라 500 을 준다
            return [URLQueryItem(name: "query", value: query)]
        }
    }

    var body: Data? {
        switch self {
        case let .save(kakaoPlaceID, query, alias):
            let encoder = NetworkJSONCoding.makeEncoder()
            return try? encoder.encode(
                PlaceSaveRequestDTO(kakaoPlaceId: kakaoPlaceID, query: query, alias: alias)
            )
        case let .updateAlias(_, alias):
            let encoder = NetworkJSONCoding.makeEncoder()
            return try? encoder.encode(PlaceAliasUpdateRequestDTO(alias: alias))
        case .savedPlaces, .search, .remove, .detail, .kakaoDetail:
            return nil
        }
    }
}
