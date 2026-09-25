import Foundation

extension Date {
    /// 지난 데이트 카드의 날짜 `26.08.16`. 코스 날짜는 Asia/Seoul 기준이라 같은 시간대로 읽는다
    var shortDateText: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
        let parts = calendar.dateComponents([.year, .month, .day], from: self)
        return String(
            format: "%02d.%02d.%02d",
            (parts.year ?? 0) % 100,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }
}
