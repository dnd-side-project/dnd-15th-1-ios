//
//  CourseErrorMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import CoreNetwork
import Domain
import Foundation

/// 명세에 코스 에러 응답이 없다. 서버 `code` 문자열을 안 읽고 HTTP 상태만 본다.
/// `code` 목록이 오면 다시 나눈다
enum CourseErrorMapper {
    static func map(_ error: Error) -> CourseError {
        if let courseError = error as? CourseError {
            return courseError
        }
        if let networkError = error as? NetworkError {
            return mapNetworkError(networkError)
        }
        return .unknown
    }

    private static func mapNetworkError(_ error: NetworkError) -> CourseError {
        switch error {
        case .transport:
            return .network
        case .unauthorized:
            return .unauthorized
        case .notFound:
            return .notFound
        case .badRequest, .forbidden, .conflict, .clientError, .serverError,
             .decodingFailed, .invalidResponse, .invalidURL:
            return .unknown
        }
    }
}
