import SharedDesignSystem
import SwiftUI

struct TermsLinksView: View {
    let onSelect: (TermsType) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(TermsType.allCases.enumerated()), id: \.element.id) { index, terms in
                if index > 0 {
                    Text("|")
                }
                Button(terms.title) {
                    onSelect(terms)
                }
            }
        }
        .buttonStyle(.plain)
        .typography(.caption2M)
        .foregroundStyle(Color.textTertiary)
    }
}
