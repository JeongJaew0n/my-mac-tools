import Foundation

/// Tool 의 설정값을 기본값으로 저장하고 되돌린다.
///
/// 저장의 뜻은 **"다음에도 이걸로 시작"** 이다. 그래서 앱을 켤 때 이 값을 읽어 매니저에
/// 넣는다. 그렇게 하지 않으면 `기본값으로 저장` 이 아무 일도 안 하는 버튼이 된다.
///
/// 저장한 적이 없으면 코드에 박힌 값을 그대로 쓴다 — 지금까지의 동작이다.
enum ToolDefaults {

    /// 잠자기 방지가 기억하는 것.
    struct Sleep: Codable, Equatable {
        var hours: Int
        var minutes: Int
        var displayDelaySeconds: Int
        var screenMode: String
        var sleepWhenDone: Bool

        /// 코드에 박힌 값. 저장된 것이 없을 때 쓴다.
        static let builtIn = Sleep(hours: 0, minutes: 0, displayDelaySeconds: 5,
                                   screenMode: "system", sleepWhenDone: false)
    }

    /// 덮어도 작업이 기억하는 것.
    struct Lid: Codable, Equatable {
        var hours: Int
        var minutes: Int

        static let builtIn = Lid(hours: 0, minutes: 0)
    }

    static func load<T: Codable>(_ key: String, fallback: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: data) else { return fallback }
        return value
    }

    static func save<T: Codable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static let sleepKey = "default.sleep"
    static let lidKey = "default.lid"
}
