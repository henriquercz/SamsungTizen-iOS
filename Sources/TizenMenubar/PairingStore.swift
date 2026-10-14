import Foundation

/// The pairing token and certificate pin for each TV address, in one file under Application
/// Support that only this user account can read. The app does not use Keychain, so reading the
/// pairing never asks for a password, not even after a rebuild. The token only lets this Mac
/// control the TV on the local network, and Forget pairing removes it.
final class PairingStore: @unchecked Sendable {
    struct Entry: Codable, Equatable {
        var token: String? = nil
        var pin: String? = nil
    }
    static let shared = PairingStore(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("br.local.TizenRemote").appendingPathComponent("pairing.json"))
    let url: URL
    private let lock = NSLock()
    init(url: URL) { self.url = url }

    func entry(_ host: String) -> Entry {
        lock.lock(); defer { lock.unlock() }
        return load()[host] ?? Entry()
    }
    func update(_ host: String, _ change: (inout Entry) -> Void) throws {
        lock.lock(); defer { lock.unlock() }
        var entries = load(), entry = entries[host] ?? Entry()
        change(&entry)
        entries[host] = entry == Entry() ? nil : entry
        try persist(entries)
    }
    private func load() -> [String: Entry] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }
    /// A private temporary file is renamed over the old one, so the token is never readable by
    /// other accounts, not even for a moment, and an interrupted save cannot leave half a file.
    private func persist(_ entries: [String: Entry]) throws {
        if entries.isEmpty {
            do { try FileManager.default.removeItem(at: url) } catch CocoaError.fileNoSuchFile {}
            return
        }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(entries)
        let temporary = directory.appendingPathComponent(".pairing-\(UUID().uuidString)")
        let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        guard fd >= 0 else { throw RemoteError.message("Could not save the TV pairing.") }
        let written = data.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, data.count) }
        close(fd)
        guard written == data.count, rename(temporary.path, url.path) == 0 else {
            unlink(temporary.path)
            throw RemoteError.message("Could not save the TV pairing.")
        }
    }
}

enum PairingToken {
    static func read(_ host: String) -> String? { PairingStore.shared.entry(host).token }
    static func save(_ key: String, host: String) throws { try PairingStore.shared.update(host) { $0.token = key } }
    /// Removes the token and the certificate pin together.
    static func delete(_ host: String) throws { try PairingStore.shared.update(host) { $0 = .init() } }
}

// Pins are private to this Mac and TV, just like the Smart View pairing token. They are
// never bundled with the app or written into a diagnostic/exported report.
enum TVCertificatePin {
    static func read(_ host: String) -> String? {
        guard let pin = PairingStore.shared.entry(host).pin, pin.count == 64, pin.allSatisfy({ $0.isHexDigit }) else { return nil }
        return pin.lowercased()
    }
    static func save(_ fingerprint: String, host: String) throws { try PairingStore.shared.update(host) { $0.pin = fingerprint } }
}
