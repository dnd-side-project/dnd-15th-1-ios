import SharedDesignSystem
import SwiftUI
import ThirdParty

/// 게시글 상세 시트. 지도 위에 얹혀 제목 · 본문 · 저장할 수 있는 곳을 보인다
public struct PostDetailView: View {
    public let store: StoreOf<PostDetailFeature>

    /// 탭바 + 홈 인디케이터. `ignoresSafeArea` 안쪽이라 여기서 재면 0 이다
    private let bottomInset: CGFloat

    /// 시트 단계. 스토어에 묶으면 붙는 스프링이 도는 내내 리듀서가 돌아 화면이 다시 만들어진다
    @State private var detent: SheetDetent = .collapsed

    public init(store: StoreOf<PostDetailFeature>, bottomInset: CGFloat) {
        self.store = store
        self.bottomInset = bottomInset
    }

    public var body: some View {
        // `header:` 를 붙인다. 빼면 above+content 이니셜라이저와 갈린다
        MapBottomSheet(
            selection: $detent,
            expandLimit: .safeAreaTop,
            header: {
                PostDetailSheetHeader(store: store)
            },
            content: {
                PostDetailSheetContent(store: store, bottomInset: bottomInset)
            }
        )
    }
}
