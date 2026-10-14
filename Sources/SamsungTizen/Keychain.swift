import Foundation
import Security

public enum PairingKey {
    static func query(_ host: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "br.local.SamsungRemote",
         kSecAttrAccount as String: host]
    }

    public static func read(_ host: String) -> String? {
        var q = query(host)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func save(_ key: String, host: String) throws {
        let q = query(host)
        let data = Data(key.utf8)
        let status = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = q
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: "Keychain", code: Int(addStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to save key"])
            }
        } else if status != errSecSuccess {
            throw NSError(domain: "Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to update key"])
        }
    }

    public static func delete(_ host: String) {
        let q = query(host)
        SecItemDelete(q as CFDictionary)
    }
}
