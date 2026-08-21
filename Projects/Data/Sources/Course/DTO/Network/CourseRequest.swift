//
//  CourseRequest.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation

struct CreateDateCourseRequestDTO: Encodable, Sendable {
    let title: String
    /// `yyyy-MM-dd`
    let date: String
    /// `HH:mm:ss`
    let time: String
}
