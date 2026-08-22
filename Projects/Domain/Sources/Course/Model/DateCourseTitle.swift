import Foundation

/// 데이트명은 사용자가 날짜 화면에서 입력하지 않는다.
/// 시안 코스 결과 화면 헤더가 `26.08.05 데이트` 라서 날짜에서 만들어 서버로 보낸다.
/// 사람이 고치는 자리는 DND-52 코스 수정 화면이다
public enum DateCourseTitle {
    public static func make(date: DateComponents) -> String {
        guard let year = date.year, let month = date.month, let day = date.day else {
            return "데이트"
        }
        return String(format: "%02d.%02d.%02d 데이트", year % 100, month, day)
    }
}
