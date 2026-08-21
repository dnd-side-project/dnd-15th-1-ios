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
        // 배너는 코스 제목을 보여준다
        UpcomingSchedule(title: dto.title, placeCount: dto.totalPlaceCount)
    }

    private static func toDateSchedule(_ dto: DateCourseResponseDTO) -> DateSchedule {
        DateSchedule(
            id: String(dto.dateCourseId),
            title: dto.title,
            placeCount: dto.totalPlaceCount,
            // 지난 데이트는 yy.MM.dd
            date: shortDate(dto.date)
        )
    }

    // "2026-08-16" → "26.08.16"
    private static func shortDate(_ raw: String) -> String {
        let parts = raw.split(separator: "-")
        guard parts.count == 3 else { return raw }
        return "\(parts[0].suffix(2)).\(parts[1]).\(parts[2])"
    }
}
