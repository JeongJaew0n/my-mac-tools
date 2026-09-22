// 이 파일은 design/tokens.json 에서 생성됩니다. 직접 고치지 마세요.
// 값을 바꾸려면 그 파일을 고치고 `scripts/build-tokens.py` 를 돌리세요.
//
// 테마: base

import CoreGraphics

/// 화면에 쓰이는 수치.
///
/// 이름은 크기가 아니라 **쓰임**으로 짓는다. `space8` 이 아니라 `inline` 이라고
/// 부르면 값을 바꿀 때 어디가 영향받는지 이름만 보고 알 수 있다.
///
/// `product` 를 뺀 나머지는 이 앱에 매이지 않는다. 다른 제품으로 가져갈 때
/// `design/tokens.json` 의 `primitive` 값만 바꾸면 된다.
enum Design {
    enum Inset {
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
        /// 타이틀바 높이. .defaultSize 는 창 전체 크기라 내용 높이에 이걸 더해야 한다
        static let titleBarHeight: CGFloat = 32
        /// 창 폭 기본값. 탭 라벨 넷이 한 줄에 들어가는 폭. 320 에서는 '로컬호스트' 가 잘린다
        static let width: CGFloat = 380
    }
}
