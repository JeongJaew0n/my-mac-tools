// 이 파일은 design/tokens.json 에서 생성됩니다. 직접 고치지 마세요.
// 값을 바꾸려면 그 파일을 고치고 `scripts/build-tokens.py` 를 돌리세요.
//
// 테마: base

import AppKit
import SwiftUI

/// 화면에 쓰이는 수치와 색.
///
/// 이름은 크기가 아니라 **쓰임**으로 짓는다. `space8` 이 아니라 `inline` 이라고
/// 부르면 값을 바꿀 때 어디가 영향받는지 이름만 보고 알 수 있다.
///
/// `product` 를 뺀 나머지는 이 앱에 매이지 않는다. 다른 제품으로 가져갈 때
/// `design/tokens.json` 의 `primitive` 값만 바꾸면 된다.
enum Design {
    enum Inset {
        /// 기본 동작 버튼 좌우
        static let buttonX: CGFloat = 12
        /// 기본 동작 버튼 위아래
        static let buttonY: CGFloat = 4
        /// 카드·항목 둘레
        static let card: CGFloat = 8
        /// 칩 좌우
        static let chipX: CGFloat = 5
        /// 칩 위아래. 글자에 붙인다
        static let chipY: CGFloat = 1
        /// 상단 탐색 아래(구분선까지)
        static let navBottom: CGFloat = 8
        /// 탐색 항목 위아래. 눌리는 영역을 키운다
        static let navItemY: CGFloat = 6
        /// 상단 탐색 위
        static let navTop: CGFloat = 10
        /// 상단 탐색 좌우
        static let navX: CGFloat = 12
        /// 오버레이 조작부와 화면 가장자리 사이
        static let overlay: CGFloat = 40
        /// 떠 있는 판 둘레
        static let panel: CGFloat = 16
        /// 화면 본문 둘레
        static let screen: CGFloat = 20
    }

    enum Radius {
        /// 목록 항목 배경
        static let card: CGFloat = 6
        /// 칩. 카드보다 작아야 안에 든 것으로 읽힌다
        static let chip: CGFloat = 3
        /// 선택된 항목 배경 등 작은 조작 요소
        static let control: CGFloat = 6
        /// 떠 있는 판
        static let panel: CGFloat = 12
    }

    enum Size {
        /// 본문의 상태 점
        static let indicator: CGFloat = 10
        /// 탐색 항목의 상태 점. 본문보다 작게 두어 위계를 만든다
        static let indicatorSmall: CGFloat = 8
        /// 탐색 항목 아이콘. 점을 대신하므로 점보다 조금 크다
        static let navIcon: CGFloat = 11
    }

    enum Space {
        /// 화면 안 블록 사이
        static let block: CGFloat = 12
        /// 여유 있는 블록 사이
        static let blockLoose: CGFloat = 16
        /// 칩·태그 사이
        static let chipGap: CGFloat = 4
        /// 설정 항목 사이
        static let formRow: CGFloat = 10
        /// 한 줄 안에서 라벨과 컨트롤 사이
        static let inline: CGFloat = 8
        /// 표시기(점·아이콘)와 그 옆 글 사이
        static let labelGap: CGFloat = 6
        /// 목록 항목 사이
        static let listItem: CGFloat = 8
        /// 목록의 줄 사이, 불릿과 글 사이
        static let listRow: CGFloat = 5
        /// 상단 탐색 항목 사이
        static let navItemGap: CGFloat = 4
        /// 간격을 주지 않는다. 구분선이 대신 가른다
        static let none: CGFloat = 0
        /// 전체 화면 오버레이의 줄 사이
        static let overlayRow: CGFloat = 12
        /// 한 덩어리로 읽혀야 하는 줄 사이. 항목 사이보다 좁다
        static let rowTight: CGFloat = 3
    }

    enum Window {
        /// 창 내용 높이 기본값. 타이틀바는 포함하지 않는다. 가장 긴 탭에 맞춰 탭을 바꿀 때 창이 튀지 않게 한다
        static let contentHeight: CGFloat = 336
        /// 창 내용 높이 최소값. 이 아래로는 ScrollView 가 받아낸다
        static let minContentHeight: CGFloat = 240
        /// 창 폭 최소값. 여기까지 줄이면 탭 라벨은 두 줄로 감기지만 본문은 멀쩡하다
        static let minWidth: CGFloat = 320
        /// 설정 창 폭. 목록 하나뿐이라 고정이다
        static let settingsWidth: CGFloat = 340
        /// 타이틀바 높이. .defaultSize 는 창 전체 크기라 내용 높이에 이걸 더해야 한다
        static let titleBarHeight: CGFloat = 32
        /// 창 폭 기본값. 탭 라벨 넷이 한 줄에 들어가는 폭. 320 에서는 '로컬호스트' 가 잘린다
        static let width: CGFloat = 380
    }

    /// 색. 테마마다 값이 다르면 **그리는 순간의 appearance** 를 따른다.
    ///
    /// SwiftUI 의 `Color` 와 이름이 같지만 `Design.Color` 로 부르므로 겹치지 않는다.
    enum Color {
        /// 강조색. 기본 동작 버튼, 토글, 초점
        static let accent = SwiftUI.Color(nsColor: AppKitColor.accent)
        /// 강조색 위 글자. 라이트 9.27, 다크 8.42
        static let onAccent = SwiftUI.Color(nsColor: AppKitColor.onAccent)
        /// 선택된 항목 글자. 6.58
        static let onSelection = SwiftUI.Color(nsColor: AppKitColor.onSelection)
        /// 선택된 항목 바탕, 칩 바탕
        static let selection = SwiftUI.Color(nsColor: AppKitColor.selection)
        /// 실패·오류
        static let statusError = SwiftUI.Color(nsColor: AppKitColor.statusError)
        /// 꺼짐
        static let statusIdle = SwiftUI.Color(nsColor: AppKitColor.statusIdle)
        /// 돌고 있음
        static let statusRunning = SwiftUI.Color(nsColor: AppKitColor.statusRunning)
        /// 곧 일어남·주의. 카운트다운, 주의사항
        static let statusWarning = SwiftUI.Color(nsColor: AppKitColor.statusWarning)
        /// 목록 항목·카드의 면. 바탕 위에 반투명으로 얹는다
        static let surface = SwiftUI.Color(nsColor: AppKitColor.surface)
        /// 보조 글자. 단위·캡션·설명·쉬는 탐색 아이콘. 바탕과 면 위에서 4.5 이상, 칩 위에는 쓰지 않는다(3.6 미만)
        static let textSecondary = SwiftUI.Color(nsColor: AppKitColor.textSecondary)
    }

    /// 같은 색의 AppKit 판. 메뉴바처럼 AppKit 으로 그리는 곳에서 쓴다.
    enum AppKitColor {
        static let accent = adaptive(light: rgb(0x38, 0x49, 0x59), dark: rgb(0x88, 0xBD, 0xF2))
        static let onAccent = adaptive(light: rgb(0xFF, 0xFF, 0xFF), dark: rgb(0x1E, 0x1E, 0x1E))
        static let onSelection = adaptive(light: rgb(0x38, 0x49, 0x59), dark: rgb(0xBD, 0xDD, 0xFC))
        static let selection = adaptive(light: rgb(0xBD, 0xDD, 0xFC), dark: rgb(0x38, 0x49, 0x59))
        static let statusError = NSColor.systemRed
        static let statusIdle = NSColor.systemGray
        static let statusRunning = NSColor.systemGreen
        static let statusWarning = NSColor.systemOrange
        static let surface = adaptive(light: rgb(0xBD, 0xDD, 0xFC, 0.32), dark: rgb(0x38, 0x49, 0x59, 0.45))
        static let textSecondary = adaptive(light: rgb(0x54, 0x72, 0x8F), dark: rgb(0x80, 0x9A, 0xB4))
    }
}

private func rgb(_ red: Int, _ green: Int, _ blue: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255, alpha: alpha)
}

/// 그리는 순간의 appearance 로 라이트·다크를 고른다. 창마다, 메뉴바마다 따로 판단된다.
private func adaptive(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    }
}
