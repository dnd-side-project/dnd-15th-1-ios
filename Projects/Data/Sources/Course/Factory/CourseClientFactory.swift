//
//  CourseClientFactory.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Domain
import Foundation

public enum CourseClientFactory {
    public static func make(session: AuthSessionAssembly) -> CourseClient {
        let repository = CourseRepository(
            remote: CourseRemoteDataSource(networkClient: session.authedClient)
        )
        return CourseClient(
            createCourse: { title, date, time in
                try await repository.createCourse(title: title, date: date, time: time)
            },
            coursePlaces: {
                try await repository.coursePlaces()
            },
            course: { try await repository.course(id: $0) },
            currentCourse: { try await repository.currentCourse() },
            latestPastCourses: { size in
                try await repository.latestPastCourses(size: size)
            },
            pastCourses: { page, size in
                try await repository.pastCourses(page: page, size: size)
            },
            updateCourse: { id, content, version in
                try await repository.updateCourse(
                    id: id,
                    content: content,
                    version: version
                )
            },
            notifyPartner: { try await repository.notifyPartner(id: $0) }
        )
    }
}
