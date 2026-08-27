import SharedDesignSystem
import SwiftUI

// 게시글 2×2 그리드 첫 로딩 자리. 탐색·검색이 함께 쓴다
struct ContentGridSkeleton: View {
    private let columns = [
        GridItem(.flexible(), spacing: 11, alignment: .top),
        GridItem(.flexible(), spacing: 11, alignment: .top),
    ]
    private let cardCount = 4

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s32) {
            ForEach(0 ..< cardCount, id: \.self) { _ in
                ContentCardSkeleton()
            }
        }
    }
}

// ContentCard 와 같은 비율·모서리·간격으로 이미지와 2줄 제목 자리를 시머로 채운다
struct ContentCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Color.clear
                .aspectRatio(170.0 / 227.0, contentMode: .fit)
                .overlay {
                    ShimmerBlock(baseColor: .gray300)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // 제목 2줄 자리. 둘째 줄은 짧게 둬 실제 텍스트처럼 보이게 한다
            VStack(alignment: .leading, spacing: 6) {
                ShimmerBlock(cornerRadius: 4, baseColor: .gray300)
                    .frame(height: 14)
                ShimmerBlock(cornerRadius: 4, baseColor: .gray300)
                    .frame(width: 60, height: 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
