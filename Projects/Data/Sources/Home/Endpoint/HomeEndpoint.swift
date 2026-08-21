//
//  HomeEndpoint.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import CoreNetwork
import Foundation

enum HomeEndpoint: APIEndpoint {
    case home
    case recentSavedPlaces(size: Int)

    var path: String {
        switch self {
        case .home:
            return "/api/v1/home"
        case .recentSavedPlaces:
            return "/api/v1/home/recent-saved-places"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .home, .recentSavedPlaces:
            return .get
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .home:
            return []
        case let .recentSavedPlaces(size):
            return [URLQueryItem(name: "size", value: String(size))]
        }
    }
}
