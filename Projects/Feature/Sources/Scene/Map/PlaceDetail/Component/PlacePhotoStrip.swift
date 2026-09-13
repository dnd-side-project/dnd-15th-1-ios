//
//  PlacePhotoStrip.swift
//  Dulpick
//

import CoreImageCache
import SharedDesignSystem
import SwiftUI

/// 장소 사진 가로 스크롤. 사진이 없으면 아무 것도 그리지 않는다
struct PlacePhotoStrip: View {
    let urls: [URL]
    @Environment(\.isSheetDragging) private var isSheetDragging

    var body: some View {
        if urls.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s4) {
                    ForEach(urls, id: \.self) { url in
                        RemoteImage(url: url, cornerRadius: PlacePhotoStripMetric.cornerRadius)
                            .frame(
                                width: PlacePhotoStripMetric.size,
                                height: PlacePhotoStripMetric.size
                            )
                    }
                }
                .padding(.horizontal, Spacing.s20)
                .padding(.top, Spacing.s16)
            }
            .scrollDisabled(isSheetDragging)
        }
    }
}

private enum PlacePhotoStripMetric {
    static let size: CGFloat = 160
    static let cornerRadius: CGFloat = 12
}
