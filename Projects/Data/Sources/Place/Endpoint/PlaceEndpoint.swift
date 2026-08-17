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

    var path: String {
        switch self {
        case .savedPlaces:
            return "/api/v1/places"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .savedPlaces:
            return .get
        }
    }
}
