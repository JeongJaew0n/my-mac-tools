import SwiftUI

/// 화면 하나를 덮는 내용. 디스플레이마다 하나씩 올라간다.
///
/// 해제 조작 안내와 버튼을 **모든 화면에** 둔다. 사용자가 어느 화면 앞에 앉아 있을지
/// 알 수 없다.
struct CoverView: View {
    let image: NSImage
    let fillMode: ScreenCoverManager.FillMode
    let dismissTitle: String
    let hint: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black

            GeometryReader { geometry in
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fillMode == .fill ? .fill : .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    // 꽉 채우기는 화면 밖으로 넘치는 부분을 잘라야 한다.
                    .clipped()
            }

            VStack {
                Spacer()
                controls
            }
            .padding(Design.Inset.overlay)
        }
        .ignoresSafeArea()
    }

    /// 사진이 무엇이든 읽히도록 반투명 판 위에 올린다.
    private var controls: some View {
        VStack(spacing: Design.Space.overlayRow) {
            Text(hint)
                .font(.callout)
                .foregroundStyle(.secondary)

            // `Return` 단축키를 붙이지 않는다. `Enter` 는 **두 번** 눌러야 풀리는 것이
            // 사양이고, 그 판정은 매니저의 키 모니터가 한다.
            Button(dismissTitle, action: onDismiss)
                .controlSize(.large)
        }
        .padding(Design.Inset.panel)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Design.Radius.panel))
    }
}
