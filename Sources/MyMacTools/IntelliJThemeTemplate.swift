import Foundation

/// IntelliJ 테마 플러그인의 틀. **색 역할** 자리에 팔레트 값을 채워 테마 JSON 과 에디터 스킴 XML 을 만든다.
///
/// 아래 두 템플릿은 사용자가 쓰던 `cmux Warm Light` 플러그인에서 **기계적으로** 뽑았다 — hex 자리를
/// 역할 이름으로 바꿨을 뿐 구조·키·글꼴 속성은 원본 그대로다. 원본에서 hex 하나가 뜻 하나였기에
/// 성립한다. 근거는 `docs/plans/intellij-theme/context.md`.
///
/// AppKit·SwiftUI 를 쓰지 않는다. 앱 밖에서 `swiftc` 로 이 파일만 묶어 결과를 검증할 수 있게.
enum IntelliJThemeTemplate {

    /// 사용자가 고르는 색 하나. 순서가 곧 화면 순서다.
    enum Role: String, CaseIterable, Codable, Identifiable {
        case editorBackground
        case panelBackground
        case text
        case accent
        case keyword
        case function
        case type
        case string
        case number
        case comment
        case panelDim
        case hover
        case selection
        case border
        case textSecondary
        case inputBackground
        case onAccent
        case scrollThumb
        case scrollThumbHover
        case editorSelection
        case caretRow
        case gutter
        case lineNumber
        case lineNumberCaret
        case indentGuide
        case indentGuideSelected
        case rightMargin
        case whitespace
        case identifierUnderCaret
        case property
        case parameter
        case annotation
        case punctuation
        case docComment
        case docTag
        case objectType
        case typeParameter
        case suspendCall
        case stringEscape
        case safeCall
        case notNullAssertion
        case mutableUnderline
        case smartCastBackground

        var id: String { rawValue }

        /// 지금 쓰는 cmux Warm Light 의 값. 불러오기의 '기본값' 이 이것이다.
        var defaultHex: String {
            switch self {
            case .editorBackground: return "FCF7ED"
            case .panelBackground: return "F8F2E8"
            case .text: return "2B2B2B"
            case .accent: return "3A7CC4"
            case .keyword: return "0033B3"
            case .function: return "8F5200"
            case .type: return "7A2F8F"
            case .string: return "067D17"
            case .number: return "1750EB"
            case .comment: return "9A9080"
            case .panelDim: return "F4EEE1"
            case .hover: return "EFE8DA"
            case .selection: return "E8DFCD"
            case .border: return "E5DDCC"
            case .textSecondary: return "7A7366"
            case .inputBackground: return "FEFBF5"
            case .onAccent: return "FFFFFF"
            case .scrollThumb: return "DDD5C5"
            case .scrollThumbHover: return "CDC3AD"
            case .editorSelection: return "DDE7F2"
            case .caretRow: return "F6F0E4"
            case .gutter: return "F9F4EA"
            case .lineNumber: return "A79E8C"
            case .lineNumberCaret: return "6B6356"
            case .indentGuide: return "E9E2D2"
            case .indentGuideSelected: return "CEC4AE"
            case .rightMargin: return "EEE7D9"
            case .whitespace: return "D7CFBD"
            case .identifierUnderCaret: return "ECE5D4"
            case .property: return "9B1D63"
            case .parameter: return "1F6B75"
            case .annotation: return "946B00"
            case .punctuation: return "5C5447"
            case .docComment: return "7D8A6A"
            case .docTag: return "5F7A4A"
            case .objectType: return "6A3F9E"
            case .typeParameter: return "9450A8"
            case .suspendCall: return "A34700"
            case .stringEscape: return "0A9B5C"
            case .safeCall: return "C2410C"
            case .notNullAssertion: return "D02020"
            case .mutableUnderline: return "C08A3E"
            case .smartCastBackground: return "ECF3E6"
            }
        }

        var section: Section {
            switch self {
            case .editorBackground, .panelBackground, .text, .accent, .keyword, .function, .type, .string, .number, .comment: return .main
            case .panelDim, .hover, .selection, .border, .textSecondary, .inputBackground, .onAccent, .scrollThumb, .scrollThumbHover: return .ui
            case .editorSelection, .caretRow, .gutter, .lineNumber, .lineNumberCaret, .indentGuide, .indentGuideSelected, .rightMargin, .whitespace, .identifierUnderCaret: return .editor
            case .property, .parameter, .annotation, .punctuation, .docComment, .docTag: return .code
            case .objectType, .typeParameter, .suspendCall, .stringEscape, .safeCall, .notNullAssertion, .mutableUnderline, .smartCastBackground: return .kotlin
            }
        }
    }

    /// `main` 은 화면에 바로 보이는 '자주 쓰는 색', 나머지는 '더 보기' 안의 묶음이다.
    enum Section: String, CaseIterable {
        case main, ui, editor, code, kotlin
    }

    /// 역할 → `RRGGBB` (대문자, `#` 없음).
    typealias Palette = [Role: String]

    /// 기본 팔레트의 이름. 이 Tool 을 만들 때 쓰던 테마다.
    static let defaultName = "cmux Warm Light"

    static var defaultPalette: Palette {
        Dictionary(uniqueKeysWithValues: Role.allCases.map { ($0, $0.defaultHex) })
    }

    /// IntelliJ 에 보일 이름. 테마와 스킴이 같은 이름을 쓴다.
    ///
    /// 프리셋 이름을 쓰지 않는다 — 바꿀 때마다 themeId 가 달라져 이전 것이 쌓인다.
    static let themeName = "MyMacTools"
    static let themeID = "mymactools-theme"
    static let pluginID = "com.jjw.mymactools.intellijtheme"
    static let pluginFolder = "mymactools-theme"
    static let themeFile = "MyMacTools.theme.json"
    static let schemeFile = "MyMacTools.xml"

    struct Rendered {
        var pluginXML: String
        var themeJSON: String
        var schemeXML: String
        var isDark: Bool
    }

    static func render(_ palette: Palette) -> Rendered {
        let isDark = luminance(palette[.editorBackground] ?? Role.editorBackground.defaultHex) < 0.5
        var values: [String: String] = [
            "themeName": themeName,
            "schemeFile": schemeFile,
            "dark": isDark ? "true" : "false",
            // 스킴이 정하지 않은 색은 부모에서 온다. 어두운 배경에 라이트 부모를 두면 안 고른 색이 튄다.
            "parentScheme": isDark ? "Darcula" : "Default",
        ]
        for role in Role.allCases {
            values[role.rawValue] = normalized(palette[role]) ?? role.defaultHex
        }
        // 테마 JSON 은 `#RRGGBB`, 스킴 XML 은 `rrggbb` 가 IntelliJ 가 쓰는 꼴이다(원본 그대로).
        var lowered = values
        for role in Role.allCases { lowered[role.rawValue] = values[role.rawValue]!.lowercased() }
        return Rendered(pluginXML: fill(pluginTemplate, values),
                        themeJSON: fill(themeTemplate, values),
                        schemeXML: fill(schemeTemplate, lowered),
                        isDark: isDark)
    }

    /// `#abc123` · `abc123` → `ABC123`. 꼴이 틀리면 `nil`.
    static func normalized(_ hex: String?) -> String? {
        guard var hex = hex?.trimmingCharacters(in: .whitespaces) else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, hex.allSatisfy(\.isHexDigit) else { return nil }
        return hex.uppercased()
    }

    /// sRGB 상대 휘도 (0 ~ 1).
    static func luminance(_ hex: String) -> Double {
        guard let hex = normalized(hex), let value = UInt32(hex, radix: 16) else { return 1 }
        func channel(_ shift: UInt32) -> Double {
            let c = Double((value >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    private static func fill(_ template: String, _ values: [String: String]) -> String {
        var result = template
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{" + key + "}}", with: value)
        }
        return result
    }

    private static let pluginTemplate = #"""
<idea-plugin>
  <id>com.jjw.mymactools.intellijtheme</id>
  <name>MyMacTools Theme</name>
  <version>1.0.0</version>
  <vendor>MyMacTools</vendor>
  <description><![CDATA[MyMacTools 의 IntelliJ 색 Tool 이 만든 테마입니다. 앱에서 적용할 때마다 다시 만들어집니다.]]></description>
  <idea-version since-build="252"/>
  <depends>com.intellij.modules.platform</depends>
  <extensions defaultExtensionNs="com.intellij">
    <themeProvider id="mymactools-theme" path="/theme/MyMacTools.theme.json"/>
  </extensions>
</idea-plugin>
"""#

    private static let themeTemplate = #"""
{
  "name": "{{themeName}}",
  "dark": {{dark}},
  "author": "MyMacTools",
  "editorScheme": "/theme/{{schemeFile}}",
  "colors": {
    "editorBackground": "#{{editorBackground}}",
    "panelBackground": "#{{panelBackground}}",
    "panelDim": "#{{panelDim}}",
    "hover": "#{{hover}}",
    "selection": "#{{selection}}",
    "border": "#{{border}}",
    "text": "#{{text}}",
    "textSecondary": "#{{textSecondary}}",
    "accent": "#{{accent}}",
    "inputBackground": "#{{inputBackground}}"
  },
  "ui": {
    "*": {
      "background": "panelBackground",
      "foreground": "text",
      "borderColor": "border",
      "separatorColor": "border",
      "disabledBackground": "panelDim",
      "disabledForeground": "textSecondary",
      "inactiveBackground": "panelBackground",
      "hoverBackground": "hover",
      "selectionBackground": "selection",
      "selectionForeground": "text",
      "selectionInactiveBackground": "hover",
      "infoForeground": "textSecondary",
      "selectedTabColor": "editorBackground"
    },
    "Panel.background": "panelBackground",
    "Editor.background": "editorBackground",
    "EditorPane.background": "editorBackground",
    "EditorTabs": {
      "background": "panelBackground",
      "underlinedTabBackground": "editorBackground",
      "underlineColor": "accent",
      "hoverBackground": "hover"
    },
    "DefaultTabs": {
      "background": "panelBackground",
      "hoverBackground": "hover",
      "underlinedTabBackground": "panelDim",
      "underlineColor": "accent"
    },
    "ToolWindow": {
      "Header.background": "panelDim",
      "Header.inactiveBackground": "panelBackground",
      "HeaderTab.selectedInactiveBackground": "hover",
      "Button.hoverBackground": "hover"
    },
    "Tree": {
      "background": "panelBackground",
      "rowHeight": 22,
      "hoverBackground": "hover",
      "selectionBackground": "selection",
      "selectionInactiveBackground": "hover"
    },
    "List": {
      "background": "panelBackground",
      "hoverBackground": "hover",
      "selectionBackground": "selection"
    },
    "Table": {
      "background": "panelBackground",
      "stripeColor": "panelDim",
      "hoverBackground": "hover"
    },
    "TextField": {
      "background": "inputBackground"
    },
    "TextArea": {
      "background": "inputBackground"
    },
    "PasswordField": {
      "background": "inputBackground"
    },
    "ComboBox": {
      "background": "inputBackground",
      "nonEditableBackground": "panelBackground",
      "ArrowButton.background": "panelBackground"
    },
    "SearchEverywhere": {
      "SearchField.background": "inputBackground",
      "Header.background": "panelDim",
      "List.separatorColor": "border"
    },
    "Popup": {
      "background": "panelBackground",
      "Header.activeBackground": "panelDim",
      "Header.inactiveBackground": "panelBackground",
      "borderColor": "border"
    },
    "PopupMenu.background": "panelBackground",
    "MenuBar.background": "panelBackground",
    "Menu.background": "panelBackground",
    "MenuItem.background": "panelBackground",
    "StatusBar.background": "panelBackground",
    "ToolBar.background": "panelBackground",
    "MainToolbar": {
      "background": "panelBackground",
      "Dropdown.hoverBackground": "hover",
      "Icon.hoverBackground": "hover"
    },
    "NewClass.Panel.background": "panelBackground",
    "ScrollBar": {
      "background": "panelBackground",
      "track": "panelBackground",
      "thumbColor": "#{{scrollThumb}}",
      "hoverThumbColor": "#{{scrollThumbHover}}"
    },
    "Button": {
      "startBackground": "inputBackground",
      "endBackground": "inputBackground",
      "startBorderColor": "border",
      "endBorderColor": "border",
      "default.startBackground": "accent",
      "default.endBackground": "accent",
      "default.foreground": "#{{onAccent}}"
    },
    "CompletionPopup": {
      "background": "inputBackground",
      "selectionBackground": "selection"
    },
    "NotificationsToolwindow.newNotification.background": "panelDim",
    "Notification.background": "inputBackground",
    "Dialog.titleColor": "panelBackground",
    "WelcomeScreen": {
      "background": "panelBackground",
      "SidePanel.background": "panelDim",
      "separatorColor": "border"
    }
  },
  "icons": {}
}
"""#

    private static let schemeTemplate = #"""
<scheme name="{{themeName}}" version="142" parent_scheme="{{parentScheme}}">
  <metaInfo>
    <property name="ide">idea</property>
  </metaInfo>
  <colors>
    <option name="CARET_ROW_COLOR" value="{{caretRow}}"/>
    <option name="GUTTER_BACKGROUND" value="{{gutter}}"/>
    <option name="INDENT_GUIDE" value="{{indentGuide}}"/>
    <option name="SELECTED_INDENT_GUIDE" value="{{indentGuideSelected}}"/>
    <option name="RIGHT_MARGIN_COLOR" value="{{rightMargin}}"/>
    <option name="SELECTION_BACKGROUND" value="{{editorSelection}}"/>
    <option name="LINE_NUMBERS_COLOR" value="{{lineNumber}}"/>
    <option name="LINE_NUMBER_ON_CARET_ROW_COLOR" value="{{lineNumberCaret}}"/>
    <option name="TEARLINE_COLOR" value="{{border}}"/>
    <option name="WHITESPACES" value="{{whitespace}}"/>
    <option name="IDENTIFIER_UNDER_CARET_ATTRIBUTES" value="{{identifierUnderCaret}}"/>
  </colors>
  <attributes>

    <!-- ===== base text ===== -->
    <option name="TEXT">
      <value>
        <option name="FOREGROUND" value="{{text}}"/>
        <option name="BACKGROUND" value="{{editorBackground}}"/>
      </value>
    </option>
    <option name="CONSOLE_NORMAL_OUTPUT">
      <value><option name="FOREGROUND" value="{{text}}"/></value>
    </option>

    <!-- ===== platform defaults (Java / YAML / JSON / Gradle / XML) ===== -->
    <option name="DEFAULT_KEYWORD">
      <value><option name="FOREGROUND" value="{{keyword}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>
    <option name="DEFAULT_CLASS_NAME">
      <value><option name="FOREGROUND" value="{{type}}"/></value>
    </option>
    <option name="DEFAULT_CLASS_REFERENCE">
      <value><option name="FOREGROUND" value="{{type}}"/></value>
    </option>
    <option name="DEFAULT_INTERFACE_NAME">
      <value><option name="FOREGROUND" value="{{type}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="DEFAULT_FUNCTION_DECLARATION">
      <value><option name="FOREGROUND" value="{{function}}"/></value>
    </option>
    <option name="DEFAULT_FUNCTION_CALL">
      <value><option name="FOREGROUND" value="{{function}}"/></value>
    </option>
    <option name="DEFAULT_STATIC_METHOD">
      <value><option name="FOREGROUND" value="{{function}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="DEFAULT_INSTANCE_FIELD">
      <value><option name="FOREGROUND" value="{{property}}"/></value>
    </option>
    <option name="DEFAULT_STATIC_FIELD">
      <value><option name="FOREGROUND" value="{{property}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="DEFAULT_PARAMETER">
      <value><option name="FOREGROUND" value="{{parameter}}"/></value>
    </option>
    <option name="DEFAULT_LOCAL_VARIABLE">
      <value><option name="FOREGROUND" value="{{text}}"/></value>
    </option>
    <option name="DEFAULT_CONSTANT">
      <value><option name="FOREGROUND" value="{{number}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="DEFAULT_STRING">
      <value><option name="FOREGROUND" value="{{string}}"/></value>
    </option>
    <option name="DEFAULT_NUMBER">
      <value><option name="FOREGROUND" value="{{number}}"/></value>
    </option>
    <option name="DEFAULT_METADATA">
      <value><option name="FOREGROUND" value="{{annotation}}"/></value>
    </option>
    <option name="DEFAULT_LINE_COMMENT">
      <value><option name="FOREGROUND" value="{{comment}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="DEFAULT_BLOCK_COMMENT">
      <value><option name="FOREGROUND" value="{{comment}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="DEFAULT_DOC_COMMENT">
      <value><option name="FOREGROUND" value="{{docComment}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="DEFAULT_DOC_COMMENT_TAG">
      <value><option name="FOREGROUND" value="{{docTag}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>
    <option name="DEFAULT_OPERATION_SIGN">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="DEFAULT_BRACES">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="DEFAULT_BRACKETS">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="DEFAULT_PARENTHS">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="DEFAULT_COMMA">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="DEFAULT_SEMICOLON">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="DEFAULT_DOT">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="DEFAULT_LABEL">
      <value><option name="FOREGROUND" value="{{annotation}}"/></value>
    </option>

    <!-- ===== Kotlin: keywords ===== -->
    <option name="KOTLIN_KEYWORD">
      <value><option name="FOREGROUND" value="{{keyword}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>
    <option name="KOTLIN_KEYWORD_VAL">
      <value><option name="FOREGROUND" value="{{keyword}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>
    <option name="KOTLIN_KEYWORD_VAR">
      <value><option name="FOREGROUND" value="{{keyword}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>

    <!-- ===== Kotlin: types (purple family) ===== -->
    <option name="KOTLIN_CLASS">
      <value><option name="FOREGROUND" value="{{type}}"/></value>
    </option>
    <option name="KOTLIN_ABSTRACT_CLASS">
      <value><option name="FOREGROUND" value="{{type}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="KOTLIN_DATA_CLASS">
      <value><option name="FOREGROUND" value="{{type}}"/></value>
    </option>
    <option name="KOTLIN_TRAIT">
      <value><option name="FOREGROUND" value="{{type}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="KOTLIN_OBJECT">
      <value><option name="FOREGROUND" value="{{objectType}}"/></value>
    </option>
    <option name="KOTLIN_DATA_OBJECT">
      <value><option name="FOREGROUND" value="{{objectType}}"/></value>
    </option>
    <option name="KOTLIN_ENUM">
      <value><option name="FOREGROUND" value="{{type}}"/></value>
    </option>
    <option name="KOTLIN_TYPE_ALIAS">
      <value><option name="FOREGROUND" value="{{type}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="KOTLIN_TYPE_PARAMETER">
      <value><option name="FOREGROUND" value="{{typeParameter}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="KOTLIN_CONSTRUCTOR">
      <value><option name="FOREGROUND" value="{{type}}"/></value>
    </option>

    <!-- ===== Kotlin: functions (brown-orange family) ===== -->
    <option name="KOTLIN_FUNCTION_DECLARATION">
      <value><option name="FOREGROUND" value="{{function}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>
    <option name="KOTLIN_FUNCTION_CALL">
      <value><option name="FOREGROUND" value="{{function}}"/></value>
    </option>
    <option name="KOTLIN_PACKAGE_FUNCTION_CALL">
      <value><option name="FOREGROUND" value="{{function}}"/></value>
    </option>
    <option name="KOTLIN_EXTENSION_FUNCTION_CALL">
      <value><option name="FOREGROUND" value="{{function}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="KOTLIN_SUSPEND_FUNCTION_CALL">
      <value><option name="FOREGROUND" value="{{suspendCall}}"/><option name="FONT_TYPE" value="3"/></value>
    </option>
    <option name="KOTLIN_DYNAMIC_FUNCTION_CALL">
      <value><option name="FOREGROUND" value="{{function}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="KOTLIN_VARIABLE_AS_FUNCTION">
      <value><option name="FOREGROUND" value="{{function}}"/></value>
    </option>

    <!-- ===== Kotlin: properties (magenta family) ===== -->
    <option name="KOTLIN_INSTANCE_PROPERTY">
      <value><option name="FOREGROUND" value="{{property}}"/></value>
    </option>
    <option name="KOTLIN_PACKAGE_PROPERTY">
      <value><option name="FOREGROUND" value="{{property}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="KOTLIN_EXTENSION_PROPERTY">
      <value><option name="FOREGROUND" value="{{property}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="KOTLIN_BACKING_FIELD_VARIABLE">
      <value><option name="FOREGROUND" value="{{property}}"/></value>
    </option>
    <option name="KOTLIN_ENUM_ENTRY">
      <value><option name="FOREGROUND" value="{{property}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>

    <!-- ===== Kotlin: variables / parameters ===== -->
    <option name="KOTLIN_LOCAL_VARIABLE">
      <value><option name="FOREGROUND" value="{{text}}"/></value>
    </option>
    <option name="KOTLIN_MUTABLE_VARIABLE">
      <value>
        <option name="FOREGROUND" value="{{text}}"/>
        <option name="EFFECT_COLOR" value="{{mutableUnderline}}"/>
        <option name="EFFECT_TYPE" value="0"/>
      </value>
    </option>
    <option name="KOTLIN_PARAMETER">
      <value><option name="FOREGROUND" value="{{parameter}}"/></value>
    </option>
    <option name="KOTLIN_NAMED_ARGUMENT">
      <value><option name="FOREGROUND" value="{{parameter}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>

    <!-- ===== Kotlin: annotations ===== -->
    <option name="KOTLIN_ANNOTATION">
      <value><option name="FOREGROUND" value="{{annotation}}"/></value>
    </option>
    <option name="KOTLIN_BUILTIN_ANNOTATION">
      <value><option name="FOREGROUND" value="{{annotation}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>

    <!-- ===== Kotlin: literals ===== -->
    <option name="KOTLIN_STRING">
      <value><option name="FOREGROUND" value="{{string}}"/></value>
    </option>
    <option name="KOTLIN_STRING_ESCAPE">
      <value><option name="FOREGROUND" value="{{stringEscape}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>
    <option name="KOTLIN_NUMBER">
      <value><option name="FOREGROUND" value="{{number}}"/></value>
    </option>
    <option name="KOTLIN_SMART_CONSTANT">
      <value><option name="FOREGROUND" value="{{number}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>

    <!-- ===== Kotlin: comments ===== -->
    <option name="KOTLIN_LINE_COMMENT">
      <value><option name="FOREGROUND" value="{{comment}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="KOTLIN_BLOCK_COMMENT">
      <value><option name="FOREGROUND" value="{{comment}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>
    <option name="KOTLIN_DOC_COMMENT">
      <value><option name="FOREGROUND" value="{{docComment}}"/><option name="FONT_TYPE" value="2"/></value>
    </option>

    <!-- ===== Kotlin: punctuation / operators ===== -->
    <option name="KOTLIN_OPERATION_SIGN">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="KOTLIN_ARROW">
      <value><option name="FOREGROUND" value="{{keyword}}"/></value>
    </option>
    <option name="KOTLIN_SAFE_ACCESS">
      <value><option name="FOREGROUND" value="{{safeCall}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>
    <option name="KOTLIN_EXCLEXCL">
      <value><option name="FOREGROUND" value="{{notNullAssertion}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>
    <option name="KOTLIN_QUEST">
      <value><option name="FOREGROUND" value="{{safeCall}}"/></value>
    </option>
    <option name="KOTLIN_COLON">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="KOTLIN_DOUBLE_COLON">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="KOTLIN_BRACES">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="KOTLIN_BRACKETS">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="KOTLIN_PARENTHESIS">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="KOTLIN_COMMA">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="KOTLIN_SEMICOLON">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="KOTLIN_DOT">
      <value><option name="FOREGROUND" value="{{punctuation}}"/></value>
    </option>
    <option name="KOTLIN_LABEL">
      <value><option name="FOREGROUND" value="{{annotation}}"/><option name="FONT_TYPE" value="1"/></value>
    </option>
    <option name="KOTLIN_SMART_CAST_VALUE">
      <value><option name="BACKGROUND" value="{{smartCastBackground}}"/></value>
    </option>
    <option name="KOTLIN_SMART_CAST_RECEIVER">
      <value><option name="BACKGROUND" value="{{smartCastBackground}}"/></value>
    </option>
  </attributes>
</scheme>
"""#
}
