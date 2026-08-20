//
//  ContentEndpoint.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Domain
import Foundation

enum ContentEndpoint: APIEndpoint {
    case contents(sort: ContentSort, page: Int, size: Int)

    var path: String {
        switch self {
        case .contents:
            return "/api/v1/contents"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .contents:
            return .get
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case let .contents(sort, page, size):
            return [
                URLQueryItem(name: "sort", value: sort.rawValue),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        }
    }
}
