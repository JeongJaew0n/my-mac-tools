import SwiftUI

/// 화면에 쓰이는 수치를 한곳에 모은다.
///
/// 지금 값들은 **코드에서 그대로 뽑아낸 것**이라, 이 파일을 도입하면서 보이는 모양은
/// 하나도 바뀌지 않았다. 정리되지 않은 부분(5 와 6, 10 과 12 가 섞여 쓰이는 등)도
/// 그대로 옮겼다. 무엇을 정규화할지는 `docs/DESIGN.md` 의 "정규화 제안" 을 보고 정한다.
///
/// 이름은 크기가 아니라 **쓰임**으로 짓는다. `spacing8` 이 아니라 `row` 라고 부르면
/// 값을 바꿀 때 어디가 영향받는지 이름만 보고 알 수 있다.
enum Design {

    /// 사이 간격.
    enum Spacing {
        /// 붙여 놓는다. 탭바와 본문은 `Divider` 가 가르므로 간격을 주지 않는다.
        static let none: CGFloat = 0
        /// 탭바 항목 사이.
        static let tabItem: CGFloat = 4
        /// 목록의 줄 사이, 그리고 불릿과 글 사이.
        static let listRow: CGFloat = 5
        /// 상태 점과 그 옆 글 사이.
        static let dotToLabel: CGFloat = 6
        /// 한 줄 안에서 라벨과 컨트롤 사이.
        static let inRow: CGFloat = 8
        /// 설정 항목 사이.
        static let settingsRow: CGFloat = 10
        /// 덮어도 작업 탭의 블록 사이.
        static let lidBlock: CGFloat = 12
        /// 잠자기 방지 탭의 블록 사이.
        static let sleepBlock: CGFloat = 16
    }

    /// 여백.
    enum Padding {
        /// 탭 본문 둘레.
        static let content: CGFloat = 20
        /// 탭바 좌우.
        static let tabBarHorizontal: CGFloat = 12
        /// 탭바 위.
        static let tabBarTop: CGFloat = 10
        /// 탭바 아래(`Divider` 까지).
        static let tabBarBottom: CGFloat = 8
        /// 탭 항목의 위아래. 눌리는 영역을 키운다.
        static let tabItemVertical: CGFloat = 6
    }

    /// 화면을 덮는 커버. 전체 화면이라 창 안의 수치와 자릿수가 다르다.
    enum Cover {
        /// 조작 판과 화면 가장자리 사이.
        static let controlsPadding: CGFloat = 40
        /// 조작 판 안의 줄 사이.
        static let controlsSpacing: CGFloat = 12
        /// 조작 판 둘레.
        static let panelPadding: CGFloat = 16
        /// 조작 판 모서리.
        static let panelCornerRadius: CGFloat = 12
        /// `Esc` 를 누르고 있는 동안의 진행 막대 너비.
        static let escapeBarWidth: CGFloat = 200
    }

    /// 크기.
    enum Size {
        /// 창 폭. 고정이다.
        static let windowWidth: CGFloat = 320
        /// 창 **내용** 높이. 타이틀바(32)는 포함하지 않는다.
        /// 두 탭 중 긴 쪽(덮어도 작업)의 내용 높이에 정확히 맞춘다.
        /// 자세한 근거는 `docs/DESIGN.md` 의 "창" 절.
        static let windowContentHeight: CGFloat = 336
        /// 본문의 상태 점.
        static let statusDot: CGFloat = 10
        /// 탭 라벨의 상태 점. 본문보다 작게 두어 위계를 만든다.
        static let tabDot: CGFloat = 8
        /// 선택된 탭 배경의 모서리.
        static let tabCornerRadius: CGFloat = 6
    }
}
