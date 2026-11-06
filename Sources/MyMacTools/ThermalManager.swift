import Combine
import Darwin
import Foundation

/// 이 맥의 발열 — OS 가 판정한 열 상태와 센서 온도(°C).
///
/// 판정은 `ProcessInfo.thermalState` 만 쓴다. 몇 도부터 뜨거운지는 우리가 정하지 않는다.
/// 온도는 숫자로 보여줄 뿐이다. 근거는 `docs/plans/thermal/spec.md`.
@MainActor
final class ThermalManager: ObservableObject {

    /// `ProcessInfo.ThermalState` 와 같은 네 단계. API 에 그대로 이름을 내보낸다.
    enum State: String {
        case nominal, fair, serious, critical

        init(_ state: ProcessInfo.ThermalState) {
            switch state {
            case .nominal: self = .nominal
            case .fair: self = .fair
            case .serious: self = .serious
            case .critical: self = .critical
            // 새 단계가 생긴다면 지금 아는 가장 높은 단계로 본다. 낮게 보여 놓치는 쪽이 더 나쁘다.
            @unknown default: self = .critical
            }
        }
    }

    /// 뜻이 분명한 센서 묶음. 이름 앞부분으로 가른다.
    ///
    /// 여기 없는 센서(`PMU tcal` 처럼 뜻을 모르는 것)는 묶지 않고 전체 목록에만 둔다.
    /// 뜻을 모르는 값을 최고값에 섞으면 숫자가 거짓말을 한다 — `tcal` 은 51.9°C 로 고정이었다.
    enum Group: String, CaseIterable {
        case die, pmuDevice, ssd, battery

        static func of(_ name: String) -> Group? {
            if name.hasPrefix("PMU tdie") { return .die }
            if name.hasPrefix("PMU tdev") { return .pmuDevice }
            if name.hasPrefix("NAND") { return .ssd }
            if name.localizedCaseInsensitiveContains("battery") { return .battery }
            return nil
        }
    }

    struct Sensor: Equatable, Identifiable {
        /// 같은 이름이 두 번씩 나온다(서비스가 둘). 이름만으로는 구분이 안 되어 순번을 붙인다.
        var id: String
        var name: String
        var celsius: Double
    }

    struct Summary: Equatable, Identifiable {
        var group: Group
        var maxCelsius: Double
        var averageCelsius: Double
        var count: Int
        var id: Group { group }
    }

    @Published private(set) var state: State
    /// 이름순. 아직 한 번도 안 읽었으면 `nil`, 읽었는데 없으면 빈 배열이다.
    @Published private(set) var sensors: [Sensor]?

    /// 묶음별 최고·평균. 센서가 없는 묶음은 빠진다.
    var summaries: [Summary] {
        guard let sensors else { return [] }
        return Group.allCases.compactMap { group in
            let values = sensors.filter { Group.of($0.name) == group }.map(\.celsius)
            guard let max = values.max() else { return nil }
            return Summary(group: group, maxCelsius: max,
                           averageCelsius: values.reduce(0, +) / Double(values.count),
                           count: values.count)
        }
    }

    /// 온도는 메모리보다 빨리 변한다. 그래도 탭이 보이는 동안만이다.
    private static let interval: TimeInterval = 2

    private var timer: Timer?
    private var stateObserver: NSObjectProtocol?
    /// 한 번 훑는 데 약 35ms 가 걸린다(실측). 메인에서 2초마다 하면 프레임을 놓친다.
    private let queue = DispatchQueue(label: "com.jjw.mymactools.thermal", qos: .utility)
    private let reader = TemperatureReader()
    /// 앞선 읽기가 안 끝났으면 다음 틱은 건너뛴다. 큐에 읽기가 쌓이지 않게.
    private var isReading = false

    init() {
        state = State(ProcessInfo.processInfo.thermalState)
        // 판정은 바뀔 때 알림이 온다. 훑지 않는다.
        stateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            let next = State(ProcessInfo.processInfo.thermalState)
            Task { @MainActor in self?.state = next }
        }
    }

    deinit {
        if let stateObserver { NotificationCenter.default.removeObserver(stateObserver) }
    }

    /// 탭이 보이는 동안만 훑는다. 다른 목록과 같은 규칙이다.
    func startPolling() {
        refresh()
        timer?.invalidate()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = Self.interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    /// 백그라운드에서 읽고 끝나면 반영한다.
    func refresh() {
        guard !isReading else { return }
        isReading = true
        let reader = reader
        queue.async { [weak self] in
            let sensors = Self.sorted(reader.read())
            Task { @MainActor in
                guard let self else { return }
                self.isReading = false
                if self.sensors != sensors { self.sensors = sensors }
            }
        }
    }

    /// 지금 값을 기다려서 읽는다. API 처럼 답을 바로 돌려줘야 할 때만 쓴다.
    func refreshNow() {
        let reader = reader
        sensors = queue.sync { Self.sorted(reader.read()) }
        state = State(ProcessInfo.processInfo.thermalState)
    }

    private nonisolated static func sorted(_ readings: [(name: String, celsius: Double)]) -> [Sensor] {
        // `tdie2` 가 `tdie10` 앞에 오게 사람 순서로 센다.
        readings
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .enumerated()
            .map { Sensor(id: "\($0.offset)", name: $0.element.name, celsius: $0.element.celsius) }
    }
}

/// IOHID 온도 센서를 읽는다. **비공개 API** 라 `dlsym` 으로 찾는다.
///
/// 링크 시점에 묶으면 심볼이 사라진 macOS 에서 앱이 아예 뜨지 않는다. 찾지 못하면 빈 배열을
/// 돌려주고, 화면은 "읽지 못함" 을 보인다 — 열 상태(공개 API)는 그대로 나온다.
///
/// 한 큐에서만 부른다(`ThermalManager.queue`). 그래서 상태를 잠그지 않는다.
private final class TemperatureReader: @unchecked Sendable {

    private typealias CreateClient = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias SetMatching = @convention(c) (AnyObject, CFDictionary) -> Int32
    private typealias CopyServices = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
    private typealias CopyProperty = @convention(c) (AnyObject, CFString) -> Unmanaged<AnyObject>?
    private typealias CopyEvent = @convention(c) (AnyObject, Int64, Int32, Int64) -> Unmanaged<AnyObject>?
    private typealias GetFloatValue = @convention(c) (AnyObject, Int32) -> Double

    /// `kIOHIDEventTypeTemperature`.
    private static let temperatureEvent: Int64 = 15
    /// 온도 이벤트의 값 필드 — 이벤트 종류를 위 16비트에 둔다.
    private static let temperatureField = Int32(15 << 16)

    private struct Functions {
        let copyServices: CopyServices
        let copyProperty: CopyProperty
        let copyEvent: CopyEvent
        let getFloatValue: GetFloatValue
    }

    private var loaded = false
    private var functions: Functions?
    private var client: AnyObject?
    private var services: [AnyObject] = []

    func read() -> [(name: String, celsius: Double)] {
        load()
        guard let functions else { return [] }
        return services.compactMap { service in
            guard let event = functions.copyEvent(service, Self.temperatureEvent, 0, 0)?.takeRetainedValue()
            else { return nil }
            let celsius = functions.getFloatValue(event, Self.temperatureField)
            // 센서가 꺼져 있으면 0 이나 말이 안 되는 값을 준다. 숫자로 보이지 않는다.
            guard celsius.isFinite, celsius > 0, celsius < 150 else { return nil }
            let name = functions.copyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String
            return (name ?? "?", celsius)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW),
              let create = dlsym(handle, "IOHIDEventSystemClientCreate"),
              let setMatching = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
              let copyServices = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
              let copyProperty = dlsym(handle, "IOHIDServiceClientCopyProperty"),
              let copyEvent = dlsym(handle, "IOHIDServiceClientCopyEvent"),
              let getFloatValue = dlsym(handle, "IOHIDEventGetFloatValue")
        else { return }

        let functions = Functions(
            copyServices: unsafeBitCast(copyServices, to: CopyServices.self),
            copyProperty: unsafeBitCast(copyProperty, to: CopyProperty.self),
            copyEvent: unsafeBitCast(copyEvent, to: CopyEvent.self),
            getFloatValue: unsafeBitCast(getFloatValue, to: GetFloatValue.self))
        guard let client = unsafeBitCast(create, to: CreateClient.self)(kCFAllocatorDefault)?.takeRetainedValue()
        else { return }
        // 0xff00 / 5 — Apple 벤더 페이지의 온도 센서.
        let matching = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary
        _ = unsafeBitCast(setMatching, to: SetMatching.self)(client, matching)

        self.functions = functions
        self.client = client
        services = (functions.copyServices(client)?.takeRetainedValue() as? [AnyObject]) ?? []
    }
}
