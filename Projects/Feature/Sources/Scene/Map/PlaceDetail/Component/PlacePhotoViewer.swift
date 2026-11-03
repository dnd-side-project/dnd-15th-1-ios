import SwiftUI
import UIKit

/// 전체 화면 사진 뷰어의 SwiftUI 입구. 화면은 전부 UIKit(`PlacePhotoViewerController`)이다.
/// 녹화 가리기가 SwiftUI 에만 붙어, 왼쪽 위 이름은 별칭이 아니라 실제 이름을 받는다
struct PlacePhotoViewer: UIViewControllerRepresentable {
    /// 연 순간의 사진 목록
    let urls: [URL]
    /// 처음 보일 사진 순번
    let initialIndex: Int
    /// 왼쪽 위 이름. 실제 장소 이름이다
    let title: String
    let onPageChanged: (Int) -> Void
    /// 닫기 애니메이션이 끝난 뒤 부른다
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> PlacePhotoViewerController {
        PlacePhotoViewerController(
            urls: urls,
            initialIndex: initialIndex,
            title: title,
            onPageChanged: onPageChanged,
            onClose: onClose
        )
    }

    // 열린 뒤에는 컨트롤러가 순번을 들고 리듀서에 알린다. 바깥 값으로 다시 맞추지 않는다
    func updateUIViewController(_ uiViewController: PlacePhotoViewerController, context: Context) {}
}
