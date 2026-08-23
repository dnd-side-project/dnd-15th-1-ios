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

    public func course(id: String) async throws -> DateCourse {
        do {
            return try CourseDTOMapper.toDomain(try await remote.detail(id: id))
        } catch {
            throw CourseErrorMapper.map(error)
        }
    }

    public func updateCourse(
        id: String,
        title: String,
        scheduledAt: Date,
        placeIDs: [String],
        version: Int
    ) async throws -> DateCourse {
        do {
            let request = SaveDateCourseRequestDTO(
                title: title,
                date: CourseDateFormat.dateText(scheduledAt),
                time: CourseDateFormat.timeText(scheduledAt),
                placeIds: try placeIDs.map { try Self.placeID(from: $0) },
                version: version
            )
            return try CourseDTOMapper.toDomain(try await remote.save(id: id, body: request))
        } catch {
            throw CourseErrorMapper.map(error)
        }
    }

    public func notifyPartner(id: String) async throws {
        do {
            _ = try await remote.notifyPartner(id: id)
        } catch {
            throw CourseErrorMapper.map(error)
        }
    }

    private static func placeID(from raw: String) throws -> Int64 {
        guard let placeID = Int64(raw) else {
            throw CourseError.unknown
        }
        return placeID
    }
}
