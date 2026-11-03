//
//  AppToggleStyle.swift
//  Dulpick
//

import SwiftUI

// 사용법: Toggle(isOn: $isOn) { Text("저장한 곳만 보기") }.toggleStyle(AppToggleStyle())
public struct AppToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.s8) {
            configuration.label

            Button {
                configuration.isOn.toggle()
            } label: {
                // 누르는 영역만 44pt 높이로 넓히고 자리는 모양 크기 그대로 둔다
                SwitchTrack(isOn: configuration.isOn)
                    .padding(AppToggleMetric.hitSlop)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(-AppToggleMetric.hitSlop)
        }
        // 기본 스위치를 접근성 표현으로 겹치면 이름 없는 스위치가 하나 더 잡힌다. 글자와 모양을 한 요소로 묶는다
        .accessibilityElement(children: .ignore)
        .accessibilityLabel { _ in configuration.label }
        .accessibilityAddTraits(.isToggle)
        // 기본 스위치와 같은 값이다
        .accessibilityValue(configuration.isOn ? "1" : "0")
        .accessibilityAction { configuration.isOn.toggle() }
    }

    private struct SwitchTrack: View {
        let isOn: Bool

        var body: some View {
            Capsule()
                .fill(isOn ? Color.gray900 : Color.gray200)
                .frame(width: AppToggleMetric.trackWidth, height: AppToggleMetric.trackHeight)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.commonWhite)
                        .frame(width: AppToggleMetric.knobSize, height: AppToggleMetric.knobSize)
                        .padding(AppToggleMetric.knobInset)
                }
                // 애니메이션을 스위치 안에 가둔다. 같은 동작에서 바뀌는 화면 상태까지 끌려 움직이지 않게 한다
                .animation(.easeInOut(duration: 0.2), value: isOn)
        }
    }
}

private enum AppToggleMetric {
    static let trackWidth: CGFloat = 40
    static let trackHeight: CGFloat = 24
    static let knobSize: CGFloat = 16
    static let knobInset: CGFloat = 4
    static let hitSlop: CGFloat = 10
}
