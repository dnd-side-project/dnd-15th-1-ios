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
            updateCourse: {
                try await repository.updateCourse(
                    id: $0,
                    title: $1,
                    scheduledAt: $2,
                    placeIDs: $3,
                    version: $4
                )
            },
            notifyPartner: { try await repository.notifyPartner(id: $0) }
        )
    }
}
