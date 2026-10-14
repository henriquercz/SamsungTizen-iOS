import Foundation
import Darwin

struct TVDevice: Identifiable, Equatable {
    var id: String { host }
    let host: String
    let name: String
    let model: String
    let mac: String?
}
private final class LocalDescriptionSession: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // A local announcement must not send the Mac to an unrelated web server.
        completionHandler(nil)
    }
}

/// The unauthenticated, read-only description every Tizen TV serves on port 8001.
struct TVInfo: Equatable {
    let name: String
    let modelName: String
    let modelCode: String
    let wifiMac: String
    let powerState: String
    let os: String
    let firmware: String
    let type: String
    var isSamsungTV: Bool { type.localizedCaseInsensitiveContains("Samsung") || os.localizedCaseInsensitiveContains("Tizen") }
    /// "[TV] Samsung 7 Series (58)" reads better without the device-class prefix.
    var displayName: String {
        let trimmed = name.hasPrefix("[TV]") ? String(name.dropFirst(4)).trimmingCharacters(in: .whitespaces) : name
        return trimmed.isEmpty ? "Samsung TV" : trimmed
    }
    /// Model codes start with the two-digit model year, such as "20_KANTSU2_UHD".
    var year: String? {
        let prefix = modelCode.prefix(3)
        guard prefix.count == 3, prefix.last == "_", let value = Int(prefix.dropLast()), (14...60).contains(value) else { return nil }
        return "20\(prefix.dropLast())"
    }
    /// Network standby still answers this endpoint, so "on" is checked explicitly.
    var isOn: Bool { powerState.isEmpty || powerState.lowercased() == "on" }
    static func parse(_ data: Data) -> TVInfo? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let device = object["device"] as? [String: Any] else { return nil }
        func text(_ key: String) -> String { (device[key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        let firmware = text("firmwareVersion")
        return TVInfo(name: text("name").isEmpty ? object["name"] as? String ?? "" : text("name"), modelName: text("modelName"), modelCode: text("model"),
                      wifiMac: text("wifiMac"), powerState: text("PowerState"), os: text("OS"),
                      firmware: firmware.lowercased() == "unknown" ? "" : firmware, type: text("type"))
    }
    static func fetch(host: String, timeout: TimeInterval = 4) async throws -> TVInfo {
        guard TizenConnection.localHost(host), let url = URL(string: "http://\(host):8001/api/v2/") else { throw RemoteError.message("Enter the TV's local IPv4 address.") }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        let session = URLSession(configuration: configuration, delegate: LocalDescriptionSession(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 262_144, let info = parse(data) else {
            throw RemoteError.message("The TV did not describe itself.")
        }
        return info
    }
}

enum TVDiscovery {
    /// Tizen TVs answer DIAL and MediaRenderer searches; older ones also announce the remote receiver.
    static let searchTargets = [
        "urn:samsung.com:device:RemoteControlReceiver:1",
        "urn:dial-multiscreen-org:service:dial:1",
        "urn:schemas-upnp-org:device:MediaRenderer:1",
    ]
    static func search() async -> [TVDevice] {
        let hosts = await Task.detached(priority: .utility) { () -> Set<String> in
            let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard fd >= 0 else { return [] }
            defer { Darwin.close(fd) }
            var timeout = timeval(tv_sec: 0, tv_usec: 400_000)
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            var address = sockaddr_in(); address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); address.sin_family = sa_family_t(AF_INET)
            address.sin_port = UInt16(1900).bigEndian; inet_pton(AF_INET, "239.255.255.250", &address.sin_addr)
            for target in searchTargets {
                let message = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: \(target)\r\n\r\n"
                message.withCString { bytes in
                    withUnsafePointer(to: &address) { ptr in ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { _ = sendto(fd, bytes, strlen(bytes), 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
                }
            }
            var hosts = Set<String>(); let end = Date().addingTimeInterval(4)
            while Date() < end {
                var buffer = [UInt8](repeating: 0, count: 16384)
                var sender = sockaddr_in()
                var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
                let count = withUnsafeMutablePointer(to: &sender) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        recvfrom(fd, &buffer, buffer.count, 0, $0, &senderLength)
                    }
                }
                guard count > 0 else { continue }
                var source = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                guard inet_ntop(AF_INET, &sender.sin_addr, &source, socklen_t(source.count)) != nil else { continue }
                let sourceHost = String(cString: source)
                let text = String(decoding: buffer.prefix(count), as: UTF8.self).lowercased()
                // Only the sender itself is probed, never an address taken from the announcement.
                if TizenConnection.localHost(sourceHost), text.contains("samsung") || text.contains("tizen") { hosts.insert(sourceHost) }
            }
            return hosts
        }.value
        let devices = await withTaskGroup(of: TVDevice?.self) { group in
            for host in hosts {
                group.addTask {
                    guard let info = try? await TVInfo.fetch(host: host), info.isSamsungTV else { return nil }
                    return TVDevice(host: host, name: info.displayName, model: info.modelName, mac: info.wifiMac.isEmpty ? nil : info.wifiMac)
                }
            }
            var found: [TVDevice] = []
            for await device in group { if let device { found.append(device) } }
            return found
        }
        return devices.sorted { $0.name < $1.name }
    }
    static func wake(mac: String, host: String) throws {
        guard TizenConnection.localHost(host) else { throw RemoteError.message("Enter the TV's local IPv4 address.") }
        let parts = mac.split(separator: ":", omittingEmptySubsequences: false)
        let bytes = parts.compactMap { UInt8($0, radix: 16) }
        guard parts.count == 6, parts.allSatisfy({ $0.count == 2 }), bytes.count == 6 else { throw RemoteError.message("Invalid MAC address.") }
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP); guard fd >= 0 else { throw RemoteError.message("Could not send the wake signal.") }
        defer { Darwin.close(fd) }
        var yes: Int32 = 1; setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
        let packet = [UInt8](repeating: 255, count: 6) + Array(repeating: bytes, count: 16).flatMap { $0 }
        for target in [host, "255.255.255.255"] {
            var address = sockaddr_in(); address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); address.sin_family = sa_family_t(AF_INET); address.sin_port = UInt16(9).bigEndian
            inet_pton(AF_INET, target, &address.sin_addr)
            let sent = packet.withUnsafeBytes { buffer in withUnsafePointer(to: &address) { ptr in ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, buffer.baseAddress, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } } }
            if sent < 0 { throw RemoteError.message("Could not send Wake-on-LAN.") }
        }
    }
}
