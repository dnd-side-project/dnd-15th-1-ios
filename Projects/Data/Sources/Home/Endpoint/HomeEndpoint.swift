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
    case pastDates(size: Int)

    var path: String {
        switch self {
        case .home:
            return "/api/v1/home"
        case .recentSavedPlaces:
            return "/api/v1/home/recent-saved-places"
        case .pastDates:
            return "/api/v1/home/past-dates"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .home, .recentSavedPlaces, .pastDates:
            return .get
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .home:
            return []
        case let .recentSavedPlaces(size), let .pastDates(size):
            return [URLQueryItem(name: "size", value: String(size))]
        }
    }
}
