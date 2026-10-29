//
//  CourseEndpoint.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import CoreNetwork
import Foundation

enum CourseEndpoint: APIEndpoint {
    case create(CreateDateCourseRequestDTO)
    case placePool
    case placeSearch(query: String?, page: Int)
    case detail(String)
    case current
    case latestPast(size: Int)
    case past(page: Int, size: Int)
    case save(String, SaveDateCourseRequestDTO)
    case notifyPartner(String)

    var path: String {
        switch self {
        case .create:
            return "/api/v1/date-courses"
        case .placePool:
            return "/api/v1/date-courses/places"
        case .placeSearch:
            return "/api/v1/date-courses/places/search"
        case let .detail(id):
            return "/api/v1/date-courses/\(id)"
        case .current:
            return "/api/v1/date-courses/current"
        case .latestPast:
            return "/api/v1/home/past-dates"
        case .past:
            return "/api/v1/date-courses/past"
        case let .save(id, _):
            return "/api/v1/date-courses/\(id)"
        case let .notifyPartner(id):
            return "/api/v1/date-courses/\(id)/notify-partner"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create, .notifyPartner:
            return .post
        case .placePool, .placeSearch, .detail, .current, .latestPast, .past:
            return .get
        case .save:
            return .put
        }
    }

    // 목록 · 검색 모두 region · category 를 보내지 않는다. 지역 필터 화면이 없고,
    // 카테고리 · 저장자는 화면이 받은 목록과 검색 결과에서 직접 거른다
    var queryItems: [URLQueryItem] {
        switch self {
        case let .placeSearch(query, page):
            return Self.placeSearchItems(query: query, page: page)
        case let .latestPast(size):
            return [URLQueryItem(name: "size", value: String(size))]
        case let .past(page, size):
            return [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        case .create, .placePool, .detail, .current, .save, .notifyPartner:
            return []
        }
    }

    var body: Data? {
        switch self {
        case let .create(request):
            return try? NetworkJSONCoding.makeEncoder().encode(request)
        case let .save(_, request):
            return try? NetworkJSONCoding.makeEncoder().encode(request)
        case .placePool, .placeSearch, .detail, .current, .latestPast, .past, .notifyPartner:
            return nil
        }
    }

    /// 검색어가 nil 이거나 비면 싣지 않는다. 서버는 생략하면 거르지 않는다.
    /// 분류 네 조건(environment·activity·time·focus)은 화면이 없어 보내지 않는다
    private static func placeSearchItems(query: String?, page: Int) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let query, !query.isEmpty {
            items.append(URLQueryItem(name: "query", value: query))
        }
        items.append(URLQueryItem(name: "page", value: String(page)))
        return items
    }
}
