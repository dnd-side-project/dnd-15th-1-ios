//
//  HomeDTOMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Domain
import Foundation

enum HomeDTOMapper {
    static func toDomain(_ dto: HomeSummaryResponseDTO) -> HomeSummary {
        HomeSummary(
            connected: dto.connected,
            myNickname: dto.myNickname ?? "",
            partnerNickname: dto.connected ? dto.partnerNickname : nil,
            // 미연결이면 현재 코스도 없다
            currentDateCourse: dto.connected ? dto.currentDateCourse.map(toUpcoming) : nil
        )
    }

    static func toPastDates(_ dtos: [DateCourseResponseDTO]) -> [DateSchedule] {
        dtos.map(toDateSchedule)
    }

    private static func toUpcoming(_ dto: DateCourseResponseDTO) -> UpcomingSchedule {
        UpcomingSchedule(date: dto.date, placeCount: dto.totalPlaceCount)
    }

    private static func toDateSchedule(_ dto: DateCourseResponseDTO) -> DateSchedule {
        DateSchedule(
            id: String(dto.dateCourseId),
            title: dto.title,
            placeCount: dto.totalPlaceCount,
            date: dto.date
        )
    }
}
