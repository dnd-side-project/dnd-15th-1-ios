import Foundation

/// 코스 저장에 실리는 제목·날짜·시간·장소. 어느 코스의 몇 번째 판인지는 안 담는다
public struct DateCourseContent: Equatable, Sendable {
    public let title: String
    public let date: Date
    public let time: DateComponents?
    public let placeIDs: [String]

    public init(
        title: String,
        date: Date,
        time: DateComponents?,
        placeIDs: [String]
    ) {
        self.title = title
        self.date = date
        self.time = time
        self.placeIDs = placeIDs
    }
}
