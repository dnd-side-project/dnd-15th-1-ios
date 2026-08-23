import Foundation
import ThirdParty

public extension CourseClient {
    static let mock = CourseClient(
        createCourse: { title, date, time in
            mockCourse(
                id: "course-mock",
                content: DateCourseContent(
                    title: title,
                    date: mockDateOnly(date: date),
                    time: time,
                    placeIDs: []
                ),
                status: .draft
            )
        },
        coursePlaces: {
            SavedPlace.mocks.map { saved in
                CoursePlaceCandidate(
                    id: saved.place.id,
                    name: saved.place.name,
                    address: saved.place.address,
                    category: saved.place.category,
                    coordinate: saved.place.coordinate,
                    ownership: saved.ownership,
                    alias: saved.alias,
                    thumbnailURLs: saved.place.thumbnailURLs
                )
            }
        },
        course: { id in
            mockCourse(
                id: id,
                content: DateCourseContent(
                    title: DateCourseTitle.make(date: mockDateComponents),
                    date: mockScheduledAt,
                    time: nil,
                    placeIDs: ["3", "4", "5"]
                ),
                status: .confirmed
            )
        },
        currentCourse: {
            DateCourseSummary(
                id: "course-mock",
                title: DateCourseTitle.make(date: mockDateComponents),
                scheduledAt: mockScheduledAt,
                status: .confirmed,
                version: 1,
                totalPlaceCount: 3
            )
        },
        updateCourse: { id, content, _ in
            mockCourse(
                id: id,
                content: content,
                status: .confirmed
            )
        },
        notifyPartner: { _ in }
    )
}

/// 시안 `c02` 요약 `3곳 · 도보 약 1시간 40분 · 총 이동 6.8km` 가 앞 두 칸에서 나온다.
/// 장소 개수가 달라지면 이 표를 순환한다
private let mockLegValues: [(walkingMinutes: Int, distanceMeters: Int)] = [
    (20, 1500),
    (80, 5300),
    (35, 2400),
    (12, 900),
]

/// 시안 `26.08.05 데이트`
private let mockScheduledAt = Date(timeIntervalSince1970: 1_785_931_200)
private let mockDateComponents = DateComponents(year: 2026, month: 8, day: 5)

private func mockDateOnly(date: DateComponents) -> Date {
    var midnight = date
    midnight.hour = 0
    midnight.minute = 0
    midnight.second = 0
    midnight.timeZone = TimeZone(identifier: "Asia/Seoul")
    return Calendar(identifier: .gregorian).date(from: midnight) ?? mockScheduledAt
}

private func mockCourse(
    id: String,
    content: DateCourseContent,
    status: CourseStatus
) -> DateCourse {
    // 확정된 코스는 한 번은 저장된 것이라 버전이 1 이다
    let version = status == .draft ? 0 : 1
    let stops = content.placeIDs
        .compactMap { placeID in Place.mocks.first { $0.id == placeID } }
        .map(CourseStop.init(place:))

    let legs = (0..<max(0, stops.count - 1)).map { index -> CourseLeg? in
        let values = mockLegValues[index % mockLegValues.count]
        return CourseLeg(
            walkingMinutes: values.walkingMinutes,
            distanceMeters: values.distanceMeters
        )
    }

    return DateCourse(
        id: id,
        title: content.title,
        scheduledDate: content.date,
        scheduledTime: content.time,
        status: status,
        version: version,
        stops: stops,
        legs: legs
    )
}
