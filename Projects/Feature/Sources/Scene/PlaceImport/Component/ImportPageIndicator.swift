//
//  ImportPageIndicator.swift
//  Dulpick
//
//  Created by 이인호 on 8/16/26.
//

import SharedDesignSystem
import SwiftUI

struct ImportPageIndicator: View {
    let pageCount: Int
    let currentPage: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { page in
                Capsule()
                    .fill(page == currentPage ? Color.textPrimary : Color.borderDefault)
                    .frame(width: page == currentPage ? 17 : 8, height: 8)
            }
        }
        .padding(.vertical, 12)
    }
}
