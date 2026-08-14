import Foundation
import ThirdParty

/// 임시 mock 데이터. 서버 명세가 나오면 통째로 걷어낸다
public extension CourseClient {
    static let mock = CourseClient(
        createCourse: { scheduledAt, placeIDs in
            mockCourse(
                id: "course-mock",
                title: mockTitle(for: scheduledAt),
                scheduledAt: scheduledAt,
                placeIDs: placeIDs
            )
        },
        course: { id in
            mockCourse(
                id: id,
                title: mockTitle(for: mockScheduledAt),
                scheduledAt: mockScheduledAt,
                placeIDs: ["3", "4", "5"]
            )
        },
        updateCourse: { id, title, scheduledAt, placeIDs in
            mockCourse(
                id: id,
                title: title,
                scheduledAt: scheduledAt,
                placeIDs: placeIDs
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

private func mockCourse(
    id: String,
    title: String,
    scheduledAt: Date,
    placeIDs: [String]
) -> DateCourse {
    let stops = placeIDs
        .compactMap { placeID in Place.mocks.first { $0.id == placeID } }
        .map(CourseStop.init(place:))

    let legs = (0..<max(0, stops.count - 1)).map { index in
        let values = mockLegValues[index % mockLegValues.count]
        return CourseLeg(
            walkingMinutes: values.walkingMinutes,
            distanceMeters: values.distanceMeters
        )
    }

    return DateCourse(
        id: id,
        title: title,
        scheduledAt: scheduledAt,
        stops: stops,
        legs: legs
    )
}

private func mockTitle(for scheduledAt: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yy.MM.dd"

    return "\(formatter.string(from: scheduledAt)) 데이트"
}
