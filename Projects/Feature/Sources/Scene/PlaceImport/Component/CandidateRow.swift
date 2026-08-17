//
//  CandidateRow.swift
//  Dulpick
//
//  Created by 이인호 on 8/16/26.
//

import Domain
import SharedDesignSystem
import SwiftUI

struct CandidateRow: View {
    let candidate: ImportCandidate
    let isSelected: Bool
    let action: () -> Void

    private var name: String {
        candidate.place?.name ?? candidate.extractedName
    }

    private var address: String {
        candidate.place?.roadAddress ?? candidate.extractedAddressHint ?? ""
    }

    private var icon: Image {
        PlaceCategory(categoryName: candidate.place?.categoryName ?? "").icon
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                icon
                    .resizable()
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .typography(.body1M)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    Text(address)
                        .typography(.caption1R)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                (isSelected ? Image.checkTrue : Image.checkFalse)
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgSubtle)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
