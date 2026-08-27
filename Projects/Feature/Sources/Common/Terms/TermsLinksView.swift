import SharedDesignSystem
import SwiftUI

struct TermsLinksView: View {
    let onSelect: (TermsType) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(TermsType.service.title) {
                onSelect(.service)
            }
            Text("|")
            Button(TermsType.privacy.title) {
                onSelect(.privacy)
            }
        }
        .buttonStyle(.plain)
        .typography(.caption2M)
        .foregroundStyle(Color.textTertiary)
    }
}
