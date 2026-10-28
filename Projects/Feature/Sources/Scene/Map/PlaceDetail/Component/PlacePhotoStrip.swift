import CoreImageCache
import SharedDesignSystem
import SwiftUI

/// 장소 사진 가로 스크롤. 사진을 누르면 그 순번을 올린다. 사진이 없으면 아무 것도 그리지 않는다
struct PlacePhotoStrip: View {
    let urls: [URL]
    let onTap: (Int) -> Void
    @Environment(\.isSheetDragging) private var isSheetDragging

    var body: some View {
        if urls.isEmpty {
            EmptyView()
        } else {
            photoScroll
        }
    }

    private var photoScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s4) {
                ForEach(Array(urls.enumerated()), id: \.element) { index, url in
                    // `Button` 은 시트를 끌어 올린 뒤 손을 떼도 눌린다. 탭 제스처는 손가락이 움직이면 실패한다
                    RemoteImage(url: url, cornerRadius: PlacePhotoStripMetric.cornerRadius)
                        .frame(
                            width: PlacePhotoStripMetric.size,
                            height: PlacePhotoStripMetric.size
                        )
                        .contentShape(RoundedRectangle(cornerRadius: PlacePhotoStripMetric.cornerRadius))
                        .onTapGesture { onTap(index) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("사진 \(index + 1)")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .padding(.horizontal, Spacing.s20)
            .padding(.top, Spacing.s16)
        }
        .scrollDisabled(isSheetDragging)
    }
}

private enum PlacePhotoStripMetric {
    static let size: CGFloat = 160
    static let cornerRadius: CGFloat = 12
}
