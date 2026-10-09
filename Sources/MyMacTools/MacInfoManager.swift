import AppKit
import Combine
import Darwin
import Foundation
import Network

/// 이 맥의 정보 — 기종·칩·macOS, 메모리·저장공간, IP.
///
/// 기준 도구와 맞추는 것이 이 Tool 의 전부다. 흔한 두 도구가 **틀린 숫자**를 준다는 것을
/// 실측으로 확인했다 — `df` 는 시스템 볼륨만 세고, `top` 은 파일 캐시까지 "used" 로 센다.
/// 근거는 `docs/plans/mac-info/context.md`.
@MainActor
final class MacInfoManager: ObservableObject {

    struct Hardware: Equatable {
        var modelName: String
        var modelIdentifier: String
        var chip: String
        var osVersion: String
        var memoryBytes: UInt64
    }

    struct Memory: Equatable {
        /// 활성 상태 보기의 "사용된 메모리" — App + Wired + 압축.
        var usedBytes: UInt64
        /// OS 가 보는 여유 비율 (`kern.memorystatus_level`).
        var freePercent: Int?
    }

    struct Storage: Equatable {
        var totalBytes: Int64
        /// Finder 와 같은 "사용 가능" — 지울 수 있는 캐시를 포함한다.
        var availableBytes: Int64
        var usedBytes: Int64 { max(0, totalBytes - availableBytes) }
    }

    struct Address: Equatable, Identifiable {
        var interface: String
        var address: String
        var id: String { interface + address }
    }

    enum Pressure: Equatable { case normal, warning, critical }

    enum PublicIP: Equatable {
        case unknown
        case loading
        case value(String)
        case failed(String)
    }

    @Published private(set) var hardware: Hardware
    @Published private(set) var memory = Memory(usedBytes: 0, freePercent: nil)
    @Published private(set) var storage: Storage?
    @Published private(set) var addresses: [Address] = []
    @Published private(set) var pressure: Pressure = .normal
    /// 인터페이스 이름 → 종류(Wi-Fi·유선…).
    @Published private(set) var interfaceKinds: [String: NWInterface.InterfaceType] = [:]
    @Published private(set) var publicIP: PublicIP = .unknown

    /// 공인 IP 를 묻는 곳. 공인 IP 하나만 문자열로 돌려준다.
    static let publicIPEndpoint = URL(string: "https://api.ipify.org")!
    private static let interval: TimeInterval = 5

    private var timer: Timer?
    private let pathMonitor = NWPathMonitor()
    private let pressureSource = DispatchSource.makeMemoryPressureSource(
        eventMask: [.normal, .warning, .critical], queue: .main)

    init() {
        hardware = Hardware(
            modelName: Self.sysctlString("hw.model") ?? "Mac",
            modelIdentifier: Self.sysctlString("hw.model") ?? "",
            chip: Self.sysctlString("machdep.cpu.brand_string") ?? "",
            osVersion: Self.osVersion(),
            memoryBytes: ProcessInfo.processInfo.physicalMemory)

        // 기종 이름은 `system_profiler` 만 사람이 읽는 꼴로 준다. 0.09초라 한 번은 싸지만
        // 메인 스레드에서 기다리지 않는다.
        Task { [weak self] in
            let name = await Task.detached(priority: .utility) { Self.marketingModelName() }.value
            if let name { self?.hardware.modelName = name }
        }

        // 메모리 압력은 OS 의 판정을 그대로 쓴다. 경계를 우리가 정하지 않는다.
        pressureSource.setEventHandler { [weak self] in
            guard let self else { return }
            let event = self.pressureSource.data
            if event.contains(.critical) { self.pressure = .critical }
            else if event.contains(.warning) { self.pressure = .warning }
            else { self.pressure = .normal }
        }
        pressureSource.resume()

        pathMonitor.pathUpdateHandler = { [weak self] path in
            var kinds: [String: NWInterface.InterfaceType] = [:]
            for interface in path.availableInterfaces { kinds[interface.name] = interface.type }
            Task { @MainActor in self?.interfaceKinds = kinds }
        }
        pathMonitor.start(queue: DispatchQueue(label: "com.jjw.mymactools.macinfo.path"))
    }

    deinit {
        pathMonitor.cancel()
        pressureSource.cancel()
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

    func refresh() {
        let nextMemory = Memory(usedBytes: Self.usedMemoryBytes() ?? memory.usedBytes,
                                freePercent: Self.sysctlInt("kern.memorystatus_level"))
        if nextMemory != memory { memory = nextMemory }

        let nextStorage = Self.storage()
        if nextStorage != storage { storage = nextStorage }

        let nextAddresses = Self.ipv4Addresses()
        if nextAddresses != addresses { addresses = nextAddresses }
    }

    /// 공인 IP 를 묻는다. **누를 때만** 부른다 — 바깥 서비스에 요청이 나간다.
    func fetchPublicIP() {
        guard publicIP != .loading else { return }
        publicIP = .loading
        var request = URLRequest(url: Self.publicIPEndpoint)
        request.timeoutInterval = 5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let result: PublicIP
            if let error {
                result = .failed(error.localizedDescription)
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                result = .failed("HTTP \(http.statusCode)")
            } else if let data,
                      let text = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                      Self.looksLikeIP(text) {
                result = .value(text)
            } else {
                result = .failed("unexpected response")
            }
            Task { @MainActor in self?.publicIP = result }
        }.resume()
    }

    func kind(of interface: String) -> NWInterface.InterfaceType? { interfaceKinds[interface] }

    // MARK: - 읽기

    /// 활성 상태 보기의 "사용된 메모리" — App + Wired + 압축.
    ///
    /// App = 익명 페이지 − 제거 가능 페이지. `top` 의 used 처럼 파일 캐시를 세지 않는다.
    /// `vm_stat` 으로 같은 정의를 계산해 대조했다.
    nonisolated static func usedMemoryBytes() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let page = UInt64(vm_kernel_page_size)
        let app = UInt64(stats.internal_page_count) &- UInt64(stats.purgeable_count)
        let wired = UInt64(stats.wire_count)
        let compressed = UInt64(stats.compressor_page_count)
        return (app + wired + compressed) * page
    }

    /// 컨테이너 기준 용량. `df` 를 쓰지 않는다 — 봉인된 시스템 볼륨만 센다.
    nonisolated static func storage() -> Storage? {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey,
                                         .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return Storage(totalBytes: Int64(total), availableBytes: available)
    }

    /// 켜진 인터페이스의 IPv4. 루프백은 뺀다.
    nonisolated static func ipv4Addresses() -> [Address] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        var found: [Address] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let flags = Int32(entry.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let addr = entry.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            found.append(Address(interface: name, address: String(cString: host)))
        }
        // en0 이 보통 주 회선이다. 이름 순이면 en0 이 앞에 온다.
        return found.sorted { $0.interface < $1.interface }
    }

    // MARK: - Private

    nonisolated private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    nonisolated private static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }

    nonisolated private static func osVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        var text = "macOS \(v.majorVersion).\(v.minorVersion)"
        if v.patchVersion > 0 { text += ".\(v.patchVersion)" }
        if let build = sysctlString("kern.osversion") { text += " (\(build))" }
        return text
    }

    /// `MacBook Pro` 같은 이름. `system_profiler` 만 이렇게 준다.
    nonisolated private static func marketingModelName() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        proc.arguments = ["SPHardwareDataType", "-json"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = object["SPHardwareDataType"] as? [[String: Any]],
              let name = items.first?["machine_name"] as? String, !name.isEmpty else { return nil }
        return name
    }

    nonisolated static func looksLikeIP(_ text: String) -> Bool {
        var v4 = in_addr()
        var v6 = in6_addr()
        return inet_pton(AF_INET, text, &v4) == 1 || inet_pton(AF_INET6, text, &v6) == 1
    }
}
