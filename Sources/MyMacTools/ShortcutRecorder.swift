import SwiftUI
import AppKit

/// 단축키를 기록받는 버튼.
///
/// 누르면 기록 모드로 들어가 **다음 키 조합 하나**를 받는다. 기록 중에는 키를 삼켜서
/// 메뉴 단축키 같은 것이 대신 발동하지 않게 한다.
struct ShortcutRecorder: View {
    let shortcut: Shortcut?
    let placeholder: String
    let recordingLabel: String
    let onChange: (Shortcut?) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(isRecording ? recordingLabel : (shortcut?.display ?? placeholder)) {
            isRecording ? stopRecording() : startRecording()
        }
        .fixedSize()
        // 기록 중에 창이 사라지면 모니터가 남는다.
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        isRecording = true
        // 등록된 조합은 핫키가 먼저 삼켜 아래 모니터에 오지 않는다. 기록하는 동안 풀어 둔다.
        HotKeyCenter.shared.pause()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let escape: UInt16 = 53
            let delete: UInt16 = 51

            switch event.keyCode {
            case escape:
                // 기록만 취소한다. 기존에 지정된 것은 그대로 둔다.
                stopRecording()
            case delete:
                // 핫키를 되살린 **뒤에** 넘긴다. 멈춘 채로 바꾸면 macOS 가 거부해도 알 수 없다.
                stopRecording()
                onChange(nil)
            default:
                // 수정자 없는 키는 받지 않는다. 기록 모드를 유지해 다시 누르게 한다.
                if let recorded = Shortcut.from(event) {
                    stopRecording()
                    onChange(recorded)
                }
            }
            return nil
        }
    }

    /// 여러 번 불려도 된다(`onDisappear`). 멈춤은 기록 중일 때만 한 번 푼다.
    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if isRecording {
            HotKeyCenter.shared.resume()
        }
        isRecording = false
    }
}
