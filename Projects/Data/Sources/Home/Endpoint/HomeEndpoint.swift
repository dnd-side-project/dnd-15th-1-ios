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

    var path: String {
        switch self {
        case .home:
            return "/api/v1/home"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .home:
            return .get
        }
    }
}
