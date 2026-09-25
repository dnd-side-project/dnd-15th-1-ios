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
        case .placePool, .detail, .current, .latestPast, .past:
            return .get
        case .save:
            return .put
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
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

    // region · category 필터는 안 보낸다. 지역 필터 UI 를 안 만들고,
    // 카테고리는 화면이 받아온 목록에서 직접 거른다
    var body: Data? {
        switch self {
        case let .create(request):
            return try? NetworkJSONCoding.makeEncoder().encode(request)
        case let .save(_, request):
            return try? NetworkJSONCoding.makeEncoder().encode(request)
        case .placePool, .detail, .current, .latestPast, .past, .notifyPartner:
            return nil
        }
    }
}
