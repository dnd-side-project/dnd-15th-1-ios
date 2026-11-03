import Domain
import Foundation

/// 장소 상세 둘째 줄에 붙이는 세부 분류 글자. 화면 형식이라 Domain 이 아니라 여기서 만든다
enum PlaceDetailCategoryText {
    /// - Parameters:
    ///   - detailCategory: 카카오 분류에서 고른 세부 분류. 없으면 nil
    ///   - category: 둘픽 분류. 세부 분류가 이 표시 이름과 같은 말이면(띄어쓰기 무시) 붙이지 않는다
    /// - Returns: 쉼표를 「/」 로 바꾼 글자. 붙일 것이 없으면 nil
    static func make(detailCategory: String?, category: PlaceCategory) -> String? {
        guard let detailCategory else { return nil }
        let text = detailCategory.replacingOccurrences(of: ",", with: "/")
        guard !text.isEmpty, spaceless(text) != spaceless(category.displayName) else { return nil }
        return text
    }

    private static func spaceless(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }
}
