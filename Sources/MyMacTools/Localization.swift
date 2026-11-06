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
        case tabCover = "tab.cover"
        case tabLocalhost = "tab.localhost"
        case tabSpeedTest = "tab.speedTest"
        case tabMacInfo = "tab.macInfo"
        case tabThermal = "tab.thermal"

        case statusWorking = "status.working"
        case statusWorkingScreenOn = "status.workingScreenOn"
        case statusWorkingPlain = "status.workingPlain"
        case statusIdle = "status.idle"

        case labelKeepWorking = "label.keepWorking"
        case labelScreenOffIn = "label.screenOffIn"
        case labelLanguage = "label.language"

        case unitHour = "unit.hour"
        case unitMinute = "unit.minute"
        case unitSecond = "unit.second"

        case toggleSleepWhenDone = "toggle.sleepWhenDone"
        case labelScreenMode = "label.screenMode"
        case screenModeSystem = "screenMode.system"
        case screenModeKeepOff = "screenMode.keepOff"
        case screenModeKeepOn = "screenMode.keepOn"
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

        // 화면 가리기
        case coverStatusOn = "cover.statusOn"
        case coverStatusOff = "cover.statusOff"
        case coverLabelImage = "cover.labelImage"
        case coverChooseImage = "cover.chooseImage"
        case coverNoImage = "cover.noImage"
        case coverLabelFillMode = "cover.labelFillMode"
        case coverFillModeFill = "cover.fillMode.fill"
        case coverFillModeFit = "cover.fillMode.fit"
        case coverDismiss = "cover.dismiss"
        case coverHint = "cover.hint"
        case coverNotALock = "cover.notALock"
        case coverImageError = "cover.imageError"
        case coverLabelShortcut = "cover.labelShortcut"
        case coverShortcutNone = "cover.shortcutNone"
        case coverShortcutRecording = "cover.shortcutRecording"
        case coverShortcutHint = "cover.shortcutHint"

        // 현재 실행중인 카페인
        case caffeineSectionTitle = "caffeine.sectionTitle"
        case caffeineEmpty = "caffeine.empty"
        case caffeineStop = "caffeine.stop"
        case caffeineOwnerThisApp = "caffeine.owner.thisApp"
        case caffeineArgsUnreadable = "caffeine.argsUnreadable"
        case caffeineStopDenied = "caffeine.stopDenied"
        case caffeineStopFailed = "caffeine.stopFailed"
        case caffeineUtility = "caffeine.utility"
        case caffeineFlagD = "caffeine.flag.d"
        case caffeineFlagI = "caffeine.flag.i"
        case caffeineFlagM = "caffeine.flag.m"
        case caffeineFlagS = "caffeine.flag.s"
        case caffeineFlagU = "caffeine.flag.u"
        case caffeineFlagT = "caffeine.flag.t"
        case caffeineFlagW = "caffeine.flag.w"

        // 로컬호스트
        case localhostStatusCount = "localhost.statusCount"
        case localhostStatusNone = "localhost.statusNone"
        case localhostOwnUserOnly = "localhost.ownUserOnly"
        case localhostEmpty = "localhost.empty"
        case localhostOpen = "localhost.open"
        case localhostStop = "localhost.stop"
        case localhostStopFailed = "localhost.stopFailed"
        case localhostSelf = "localhost.self"
        case localhostLabelSystem = "localhost.label.system"
        case localhostLabelSystemHelp = "localhost.label.systemHelp"
        case localhostLabelTerminal = "localhost.label.terminal"
        case localhostLabelTerminalHelp = "localhost.label.terminalHelp"
        case localhostLabelWellKnown = "localhost.label.wellKnown"
        case localhostLabelWellKnownHelp = "localhost.label.wellKnownHelp"
        case localhostConfirmTitle = "localhost.confirmTitle"
        case localhostConfirmBody = "localhost.confirmBody"
        case localhostConfirmStop = "localhost.confirmStop"
        case localhostConfirmCancel = "localhost.confirmCancel"
        case localhostCategoryAll = "localhost.category.all"
        case localhostCategoryOther = "localhost.category.other"
        case localhostSearchPrompt = "localhost.searchPrompt"
        case localhostNoMatch = "localhost.noMatch"
        case localhostShowingCount = "localhost.showingCount"

        // 속도 측정
        case speedDownload = "speed.download"
        case speedUpload = "speed.upload"
        case speedResponsiveness = "speed.responsiveness"
        case speedResponsivenessHelp = "speed.responsivenessHelp"
        case speedLatency = "speed.latency"
        case speedStart = "speed.start"
        case speedCancel = "speed.cancel"
        case speedRunning = "speed.running"
        case speedNever = "speed.never"
        case speedFailed = "speed.failed"
        case speedDataNote = "speed.dataNote"
        case speedMeasuredAt = "speed.measuredAt"
        case speedHistory = "speed.history"
        case speedClearHistory = "speed.clearHistory"
        case speedExpensiveTitle = "speed.expensiveTitle"
        case speedExpensiveBody = "speed.expensiveBody"
        case speedExpensiveGo = "speed.expensiveGo"
        case usageTitle = "usage.title"
        case usageNote = "usage.note"
        case usageVideo4K = "usage.video4K"
        case usageVideo1080p = "usage.video1080p"
        case usageVideo720p = "usage.video720p"
        case usageCall1080p = "usage.call1080p"
        case usageCallGroup720p = "usage.callGroup720p"
        case usageGigabyte = "usage.gigabyte"
        case usageSeconds = "usage.seconds"
        case usageMinutes = "usage.minutes"
        case usageHours = "usage.hours"

        // Mac 정보
        case infoMemory = "info.memory"
        case infoStorage = "info.storage"
        case infoUsedOfTotal = "info.usedOfTotal"
        case infoFree = "info.free"
        case infoPressure = "info.pressure"
        case infoPressureNormal = "info.pressure.normal"
        case infoPressureWarning = "info.pressure.warning"
        case infoPressureCritical = "info.pressure.critical"
        case infoFreePercent = "info.freePercent"
        case infoLocalIP = "info.localIP"
        case infoPublicIP = "info.publicIP"
        case infoMAC = "info.mac"
        case infoMACPrivate = "info.macPrivate"
        case infoMACPrivateHelp = "info.macPrivateHelp"
        case infoHardwareMAC = "info.hardwareMAC"
        case infoPublicIPCheck = "info.publicIPCheck"
        case infoPublicIPNote = "info.publicIPNote"
        case infoPublicIPFailed = "info.publicIPFailed"
        case infoNoNetwork = "info.noNetwork"
        case infoCopy = "info.copy"
        case infoCopied = "info.copied"
        case infoMemoryHelp = "info.memoryHelp"
        case infoStorageHelp = "info.storageHelp"

        // 발열
        case thermalState = "thermal.state"
        case thermalStateNominal = "thermal.state.nominal"
        case thermalStateFair = "thermal.state.fair"
        case thermalStateSerious = "thermal.state.serious"
        case thermalStateCritical = "thermal.state.critical"
        case thermalStateHelp = "thermal.stateHelp"
        case thermalGroupDie = "thermal.group.die"
        case thermalGroupPMUDevice = "thermal.group.pmuDevice"
        case thermalGroupSSD = "thermal.group.ssd"
        case thermalGroupBattery = "thermal.group.battery"
        case thermalMaxAverage = "thermal.maxAverage"
        case thermalAllSensors = "thermal.allSensors"
        case thermalSensorNote = "thermal.sensorNote"
        case thermalUnavailable = "thermal.unavailable"

        // IntelliJ 색
        case tabIntelliJTheme = "tab.intellijTheme"
        case intellijTargetMissing = "intellij.targetMissing"
        case intellijCurrentTheme = "intellij.currentTheme"
        case intellijCurrentThemeOurs = "intellij.currentThemeOurs"
        case intellijThemeDefault = "intellij.themeDefault"
        case intellijSectionMain = "intellij.section.main"
        case intellijSectionUI = "intellij.section.ui"
        case intellijSectionEditor = "intellij.section.editor"
        case intellijSectionCode = "intellij.section.code"
        case intellijSectionKotlin = "intellij.section.kotlin"
        case intellijMore = "intellij.more"
        case intellijColorHelp = "intellij.colorHelp"
        case intellijPresets = "intellij.presets"
        case intellijPresetName = "intellij.presetName"
        case intellijSave = "intellij.save"
        case intellijOverwrite = "intellij.overwrite"
        case intellijLoad = "intellij.load"
        case intellijLoadDefault = "intellij.loadDefault"
        case intellijDelete = "intellij.delete"
        case intellijPresetSaved = "intellij.presetSaved"
        case intellijPresetLoaded = "intellij.presetLoaded"
        case intellijApply = "intellij.apply"
        case intellijApplyNote = "intellij.applyNote"
        case intellijRestore = "intellij.restore"
        case intellijConfirmApplyTitle = "intellij.confirmApplyTitle"
        case intellijConfirmRestoreTitle = "intellij.confirmRestoreTitle"
        case intellijConfirmBody = "intellij.confirmBody"
        case intellijConfirmApply = "intellij.confirmApply"
        case intellijConfirmRestore = "intellij.confirmRestore"
        case intellijStepQuitting = "intellij.step.quitting"
        case intellijStepWriting = "intellij.step.writing"
        case intellijStepRelaunching = "intellij.step.relaunching"
        case intellijApplied = "intellij.applied"
        case intellijAppliedNotRunning = "intellij.appliedNotRunning"
        case intellijRestored = "intellij.restored"
        case intellijRestoredNotRunning = "intellij.restoredNotRunning"
        case intellijFailNoConfig = "intellij.failNoConfig"
        case intellijFailDidNotQuit = "intellij.failDidNotQuit"
        case intellijFailNothingToRestore = "intellij.failNothingToRestore"
        case intellijFailWrite = "intellij.failWrite"
        case intellijRoleEditorBackground = "intellij.role.editorBackground"
        case intellijRolePanelBackground = "intellij.role.panelBackground"
        case intellijRoleText = "intellij.role.text"
        case intellijRoleAccent = "intellij.role.accent"
        case intellijRoleKeyword = "intellij.role.keyword"
        case intellijRoleFunction = "intellij.role.function"
        case intellijRoleType = "intellij.role.type"
        case intellijRoleString = "intellij.role.string"
        case intellijRoleNumber = "intellij.role.number"
        case intellijRoleComment = "intellij.role.comment"
        case intellijRolePanelDim = "intellij.role.panelDim"
        case intellijRoleHover = "intellij.role.hover"
        case intellijRoleSelection = "intellij.role.selection"
        case intellijRoleBorder = "intellij.role.border"
        case intellijRoleTextSecondary = "intellij.role.textSecondary"
        case intellijRoleInputBackground = "intellij.role.inputBackground"
        case intellijRoleOnAccent = "intellij.role.onAccent"
        case intellijRoleScrollThumb = "intellij.role.scrollThumb"
        case intellijRoleScrollThumbHover = "intellij.role.scrollThumbHover"
        case intellijRoleEditorSelection = "intellij.role.editorSelection"
        case intellijRoleCaretRow = "intellij.role.caretRow"
        case intellijRoleGutter = "intellij.role.gutter"
        case intellijRoleLineNumber = "intellij.role.lineNumber"
        case intellijRoleLineNumberCaret = "intellij.role.lineNumberCaret"
        case intellijRoleIndentGuide = "intellij.role.indentGuide"
        case intellijRoleIndentGuideSelected = "intellij.role.indentGuideSelected"
        case intellijRoleRightMargin = "intellij.role.rightMargin"
        case intellijRoleWhitespace = "intellij.role.whitespace"
        case intellijRoleIdentifierUnderCaret = "intellij.role.identifierUnderCaret"
        case intellijRoleProperty = "intellij.role.property"
        case intellijRoleParameter = "intellij.role.parameter"
        case intellijRoleAnnotation = "intellij.role.annotation"
        case intellijRolePunctuation = "intellij.role.punctuation"
        case intellijRoleDocComment = "intellij.role.docComment"
        case intellijRoleDocTag = "intellij.role.docTag"
        case intellijRoleObjectType = "intellij.role.objectType"
        case intellijRoleTypeParameter = "intellij.role.typeParameter"
        case intellijRoleSuspendCall = "intellij.role.suspendCall"
        case intellijRoleStringEscape = "intellij.role.stringEscape"
        case intellijRoleSafeCall = "intellij.role.safeCall"
        case intellijRoleNotNullAssertion = "intellij.role.notNullAssertion"
        case intellijRoleMutableUnderline = "intellij.role.mutableUnderline"
        case intellijRoleSmartCastBackground = "intellij.role.smartCastBackground"

        // 설정 창
        case settingsAppearanceTitle = "settings.appearanceTitle"
        case settingsAppearanceNote = "settings.appearanceNote"
        case appearanceSystem = "appearance.system"
        case appearanceLight = "appearance.light"
        case appearanceDark = "appearance.dark"
        case settingsTabsTitle = "settings.tabsTitle"
        case settingsTabsNote = "settings.tabsNote"
        case settingsTabsLastOne = "settings.tabsLastOne"
        case settingsMenu = "settings.menu"
        case settingsOpen = "settings.open"
        case buttonSaveAsDefault = "button.saveAsDefault"
        case buttonRestoreDefault = "button.restoreDefault"
        case captionDefaults = "caption.defaults"
        case captionDefaultsMenuBar = "caption.defaultsMenuBar"

        // 메뉴바
        case menuOpenWindow = "menu.openWindow"
        case menuQuit = "menu.quit"

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
