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
        // course / updateCourse / notifyPartner 는 부르는 화면이 없어 mock 유지.
        // DND-52 데이트 코스 결과 화면이 붙인다
        return CourseClient(
            createCourse: { title, date, time in
                try await repository.createCourse(title: title, date: date, time: time)
            },
            coursePlaces: {
                try await repository.coursePlaces()
            },
            course: CourseClient.mock.course,
            updateCourse: CourseClient.mock.updateCourse,
            notifyPartner: CourseClient.mock.notifyPartner
        )
    }
}
