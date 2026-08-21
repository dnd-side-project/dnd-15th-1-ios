//
//  CourseRepository.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Domain
import Foundation

public struct CourseRepository: Sendable {
    private let remote: CourseRemoteDataSource

    public init(remote: CourseRemoteDataSource) {
        self.remote = remote
    }

    public func createCourse(
        title: String,
        date: DateComponents,
        time: DateComponents
    ) async throws -> DateCourse {
        do {
            let request = CreateDateCourseRequestDTO(
                title: title,
                date: CourseDateFormat.dateText(date),
                time: CourseDateFormat.timeText(time)
            )
            return try CourseDTOMapper.toDomain(try await remote.create(request))
        } catch {
            throw CourseErrorMapper.map(error)
        }
    }

    public func coursePlaces() async throws -> [CoursePlaceCandidate] {
        do {
            return try await remote.placePool().places.map(CourseDTOMapper.toDomain)
        } catch {
            throw CourseErrorMapper.map(error)
        }
    }
}
