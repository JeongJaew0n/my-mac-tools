import CoreAudio

/// 기본 출력 장치의 음소거. 잠자기 방지가 화면을 끌 때 쓴다(`BlackWorkManager.muteWhileOff`).
///
/// CoreAudio 의 장치 속성이라 권한이 필요 없다. 모든 장치가 음소거를 갖지는 않는다 —
/// 그런 장치면 `mute()` 가 `nil` 을 돌려준다.
enum OutputMute {
    /// 음소거하기 전의 상태. 되돌릴 때 이것만 본다.
    struct Previous: Equatable {
        let device: AudioObjectID
        let wasMuted: Bool
    }

    /// 지금 기본 출력 장치를 음소거하고, 되돌릴 정보를 준다. 못 하면 `nil`.
    static func mute() -> Previous? {
        guard let device = defaultOutputDevice(),
              let wasMuted = isMuted(device) else { return nil }
        // 이미 음소거면 건드릴 것이 없다. 되돌릴 때도 그대로 둔다.
        guard wasMuted || setMuted(true, device) else { return nil }
        return Previous(device: device, wasMuted: wasMuted)
    }

    /// 음소거하기 전으로 되돌린다. **원래 음소거였으면 아무것도 안 한다** —
    /// 사용자가 꺼둔 소리를 앱이 켜면 안 된다.
    ///
    /// 그 사이에 장치를 뺐으면 실패하는데, 되돌릴 대상이 없어진 것이라 그냥 둔다.
    static func restore(_ previous: Previous) {
        guard !previous.wasMuted else { return }
        _ = setMuted(false, previous.device)
    }

    private static var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
    }

    private static func defaultOutputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        guard status == noErr, device != kAudioObjectUnknown else { return nil }
        return device
    }

    /// 음소거를 바꿀 수 없는 장치면 `nil`.
    private static func isMuted(_ device: AudioObjectID) -> Bool? {
        var address = muteAddress
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(device, &address),
              AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
              settable.boolValue else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value != 0
    }

    private static func setMuted(_ muted: Bool, _ device: AudioObjectID) -> Bool {
        var address = muteAddress
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr
    }
}
