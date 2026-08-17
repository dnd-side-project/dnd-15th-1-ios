//
//  ContentEndpoint.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Foundation

enum ContentEndpoint: APIEndpoint {
    case contents(page: Int, size: Int)

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

    // sort 는 서버 기본 정렬(최신순)에 맡기고 page/size 만 넘김
    var queryItems: [URLQueryItem] {
        switch self {
        case let .contents(page, size):
            return [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        }
    }
}
