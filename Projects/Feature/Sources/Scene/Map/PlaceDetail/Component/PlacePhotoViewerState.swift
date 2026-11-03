import Foundation

/// 전체 화면 사진 뷰어가 열려 있는 동안의 값
struct PlacePhotoViewerState: Equatable, Sendable {
    /// 연 순간의 사진 목록. 넘기는 도중 상세 응답이 와도 바꾸지 않아 사진이 튀지 않는다
    let urls: [URL]
    /// 지금 보는 사진 순번
    var currentIndex: Int
}
