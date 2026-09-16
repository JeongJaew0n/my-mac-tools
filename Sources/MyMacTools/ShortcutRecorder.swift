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
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let escape: UInt16 = 53
            let delete: UInt16 = 51

            switch event.keyCode {
            case escape:
                // 기록만 취소한다. 기존에 지정된 것은 그대로 둔다.
                stopRecording()
            case delete:
                onChange(nil)
                stopRecording()
            default:
                // 수정자 없는 키는 받지 않는다. 기록 모드를 유지해 다시 누르게 한다.
                if let recorded = Shortcut.from(event) {
                    onChange(recorded)
                    stopRecording()
                }
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
    }
}
