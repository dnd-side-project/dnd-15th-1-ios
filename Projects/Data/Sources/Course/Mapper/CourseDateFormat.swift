//
//  CourseDateFormat.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation

/// 보내는 형식과 받는 형식이 같은 약속이라 한 파일에 둔다
enum CourseDateFormat {
    /// DateComponents -> "yyyy-MM-dd"
    static func dateText(_ date: DateComponents) -> String {
        String(
            format: "%04d-%02d-%02d",
            date.year ?? 0,
            date.month ?? 0,
            date.day ?? 0
        )
    }

    /// DateComponents -> "HH:mm:ss"
    static func timeText(_ time: DateComponents) -> String {
        String(format: "%02d:%02d:00", time.hour ?? 0, time.minute ?? 0)
    }

    static func dateText(_ date: Date) -> String {
        dateText(seoulComponents([.year, .month, .day], from: date))
    }

    static func timeText(_ date: Date) -> String {
        timeText(seoulComponents([.hour, .minute], from: date))
    }

    /// "yyyy-MM-dd" + "HH:mm:ss" -> Date. 못 읽으면 nil.
    /// 서버가 초 0 이면 초를 생략해 보내서 두 형식을 다 받는다
    static func date(from date: String, time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let raw = "\(date) \(time)"

        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let scheduledAt = formatter.date(from: raw) {
            return scheduledAt
        }

        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let scheduledAt = formatter.date(from: raw) {
            return scheduledAt
        }

        return nil
    }

    /// "2026-08-30" → Asia/Seoul 그 날 자정
    static func date(from date: String) -> Date? {
        Self.date(from: date, time: "00:00:00")
    }

    /// 못 읽은 조각을 떨어뜨리면 초가 분 자리로 올라온다
    static func timeComponents(from time: String) -> DateComponents? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute)
        else { return nil }
        return DateComponents(hour: hour, minute: minute)
    }

    private static func seoulComponents(
        _ components: Set<Calendar.Component>,
        from date: Date
    ) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
        return calendar.dateComponents(components, from: date)
    }
}
