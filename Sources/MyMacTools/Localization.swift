import Foundation
import Combine

/// 앱에서 고를 수 있는 언어. `system` 은 macOS 시스템 언어를 따른다.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case ko
    case en
    case ja

    var id: String { rawValue }

    /// 선택 메뉴에 보일 이름.
    /// 실제 언어 항목은 그 언어의 자기 이름으로 두어 어떤 언어에서든 알아볼 수 있게 한다.
    func displayName(_ l10n: L10n) -> String {
        switch self {
        case .system: return l10n(.languageSystem)
        case .ko: return "한국어"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
}

/// `.lproj` 번들에서 문자열을 꺼내온다.
///
/// SwiftPM 의 `Bundle.module` 은 쓰지 않는다. 생성되는 접근자가
/// `Bundle.main.bundleURL/<이름>.bundle` 과 하드코딩된 빌드 경로만 뒤져서,
/// 손으로 조립한 `.app` 에서는 `.build` 가 사라지는 순간 `fatalError` 로 죽는다.
/// 대신 표준 위치(`Contents/Resources/*.lproj`)를 `Bundle.main` 으로 읽는다.
/// 자세한 근거는 `docs/i18n-design.md`.
final class L10n: ObservableObject {
    enum Key: String, CaseIterable {
        // 상단 탭
        case tabScreenOff = "tab.screenOff"
        case tabLid = "tab.lid"

        case statusWorking = "status.working"
        case statusIdle = "status.idle"

        case labelKeepWorking = "label.keepWorking"
        case labelScreenOffIn = "label.screenOffIn"
        case labelLanguage = "label.language"

        case unitHour = "unit.hour"
        case unitMinute = "unit.minute"
        case unitSecond = "unit.second"

        case toggleSleepWhenDone = "toggle.sleepWhenDone"
        case toggleKeepScreenOff = "toggle.keepScreenOff"
        case buttonStart = "button.start"
        case buttonStop = "button.stop"

        case captionUnlimited = "caption.unlimited"
        case captionWillSleep = "caption.willSleep"
        case captionNormalSleep = "caption.normalSleep"
        case captionSleepBlockedByLid = "caption.sleepBlockedByLid"

        // 덮개 닫아도 작업 진행
        case lidStatusOn = "lid.statusOn"
        case lidStatusOff = "lid.statusOff"
        case lidCautionTitle = "lid.cautionTitle"
        case lidCautionPower = "lid.caution.power"
        case lidCautionHeat = "lid.caution.heat"
        case lidCautionSurface = "lid.caution.surface"
        case lidCautionStop = "lid.caution.stop"
        case lidError = "lid.error"
        case lidAutoStopFailed = "lid.autoStopFailed"

        // 켜진 채로 종료하려 할 때의 경고
        case quitTitle = "quit.title"
        case quitBody = "quit.body"
        case quitStopAndQuit = "quit.stopAndQuit"
        case quitAnyway = "quit.anyway"
        case quitCancel = "quit.cancel"

        case progressScreenOff = "progress.screenOff"
        case progressRemaining = "progress.remaining"
        case progressNoLimit = "progress.noLimit"
        case progressReblank = "progress.reblank"
        case statusKeepOffFailed = "status.keepOffFailed"

        case languageSystem = "language.system"
    }

    /// `.lproj` 로 존재하는 언어 코드
    static let supportedCodes = ["en", "ko", "ja"]
    private static let fallbackCode = "en"
    private static let storageKey = "appLanguage"

    @Published var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
            bundle = Self.bundle(for: language)
        }
    }

    private var bundle: Bundle

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        let restored = saved.flatMap(AppLanguage.init(rawValue:)) ?? .system
        language = restored
        bundle = Self.bundle(for: restored)
    }

    /// 값이 없으면 키를 그대로 돌려준다. 누락을 화면에서 바로 알아볼 수 있다.
    func callAsFunction(_ key: Key) -> String {
        bundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)
    }

    func callAsFunction(_ key: Key, _ arguments: CVarArg...) -> String {
        String(format: callAsFunction(key), arguments: arguments)
    }

    /// 지금 실제로 쓰이는 언어 코드. 검증용.
    var activeCode: String {
        bundle.bundleURL.deletingPathExtension().lastPathComponent
    }

    // MARK: - Private

    private static func bundle(for language: AppLanguage) -> Bundle {
        let code: String
        switch language {
        case .system:
            let preferred = Bundle.main.preferredLocalizations.first ?? fallbackCode
            code = supportedCodes.contains(preferred) ? preferred : fallbackCode
        case .ko, .en, .ja:
            code = language.rawValue
        }
        return lproj(code) ?? lproj(fallbackCode) ?? .main
    }

    private static func lproj(_ code: String) -> Bundle? {
        Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
    }
}
