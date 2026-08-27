//
//  HomeHeader.swift
//  Dulpick
//
//  Created by 이인호 on 8/10/26.
//

import SharedDesignSystem
import SwiftUI

struct HomeHeader: View {
    let nickname: String
    let partnerName: String?
    let calendarTapped: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Image.brandMark

            Spacer()

            HStack(spacing: 2) {
                Text(nickname)
                    .typography(.body2M)
                    .foregroundStyle(Color.textInverse)

                if let partnerName {
                    Image.heart
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(Color.textInverse)

                    Text(partnerName)
                        .typography(.body2M)
                        .foregroundStyle(Color.textInverse)
                }
            }
            .padding(.trailing, 8)

            Button(action: calendarTapped) {
                Image.dateCalendar
                    .renderingMode(.template)
                    .foregroundStyle(Color.textInverseTertiary)
                    .frame(width: 44, height: 44)
                    .background(Color.gray800)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
