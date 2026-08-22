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
    case search(query: String, sort: ContentSort, page: Int, size: Int)

    var path: String {
        switch self {
        case .contents:
            return "/api/v1/contents"
        case .search:
            return "/api/v1/contents/search"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .contents, .search:
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
        case let .search(query, sort, page, size):
            return [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "sort", value: sort.rawValue),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        }
    }
}
