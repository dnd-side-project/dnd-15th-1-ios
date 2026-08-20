//
//  PlaceAliasView.swift
//  Dulpick
//

import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct PlaceAliasView: View {
    @Bindable public var store: StoreOf<PlaceAliasFeature>

    @State private var isAliasFocused = false

    public init(store: StoreOf<PlaceAliasFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("장소 명칭 수정")
                .typography(.headline)
                .foregroundStyle(Color.textPrimary)
                .padding(.bottom, Spacing.s16)

            AppTextField(
                text: $store.alias,
                placeholder: store.placeName,
                size: .large,
                style: .filled,
                accessory: .clear,
                sanitize: PlaceAliasFeature.sanitizedAlias,
                isFocused: $isAliasFocused,
                onSubmit: { isAliasFocused = false }
            )
            .padding(.bottom, Spacing.s8)

            Text(store.address)
                .typography(.body2M)
                .foregroundStyle(Color.textTertiary)
                .padding(.vertical, Spacing.s4)
                .padding(.horizontal, Spacing.s8)
                .padding(.bottom, 50)

            AppButton("저장", style: .primary, size: .xl, fullWidth: true) {
                store.send(.saveTapped)
            }
            .disabled(!store.isSaveEnabled)
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.bottom, Spacing.s20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { isAliasFocused = true }
    }
}
