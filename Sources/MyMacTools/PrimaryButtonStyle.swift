import SwiftUI

/// 기본 동작 버튼. 강조색 바탕에 `onAccent` 글자를 그린다.
///
/// macOS 의 기본 버튼(`.keyboardShortcut(.defaultAction)`)은 강조색 위에 **흰 글자**를
/// 그린다. 다크의 강조색 `sky400` 은 밝아서 흰 글자가 1.98 로 읽히지 않는다. 그래서
/// 글자색까지 토큰으로 정하는 이 스타일을 쓴다. Return 키는 `.keyboardShortcut` 이 그대로 받는다.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.medium)
            .foregroundStyle(Design.Color.onAccent)
            .padding(.horizontal, Design.Inset.buttonX)
            .padding(.vertical, Design.Inset.buttonY)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.control)
                    .fill(Design.Color.accent))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .contentShape(Rectangle())
    }
}
