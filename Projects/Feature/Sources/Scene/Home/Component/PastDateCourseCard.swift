//
//  PastDateCourseCard.swift
//  Dulpick
//
//  Created by 이인호 on 8/10/26.
//

import Domain
import SharedDesignSystem
import SwiftUI

struct PastDateCourseCard: View {
    let course: DateCourseSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(course.title)
                .typography(.body1M)
                .foregroundStyle(Color.textPrimary)

            HStack {
                HStack(spacing: 2) {
                    Image.mappin
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.primaryPink)

                    Text("총 \(course.totalPlaceCount)곳의 장소")
                        .typography(.body2M)
                        .foregroundStyle(Color.brandPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.commonWhite)
                .clipShape(Capsule())

                Spacer()

                Text(course.scheduledAt.shortDateText)
                    .typography(.caption1R)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(width: 333, alignment: .leading)
        .background(Color.bgSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
