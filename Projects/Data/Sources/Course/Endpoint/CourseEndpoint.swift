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

    var path: String {
        switch self {
        case .create:
            return "/api/v1/date-courses"
        case .placePool:
            return "/api/v1/date-courses/places"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .create:
            return .post
        case .placePool:
            return .get
        }
    }

    // region · category 필터는 안 보낸다. 지역 필터 UI 를 안 만들고,
    // 카테고리는 화면이 받아온 목록에서 직접 거른다
    var body: Data? {
        switch self {
        case let .create(request):
            return try? NetworkJSONCoding.makeEncoder().encode(request)
        case .placePool:
            return nil
        }
    }
}
