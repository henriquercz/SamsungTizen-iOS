import AppKit

enum ConnectionTrustPrompt {
    @MainActor static func confirm(host: String, fingerprint: String) async -> Bool {
        let alert = NSAlert()
        alert.messageText = "Trust this Samsung TV?"
        alert.informativeText = "Connect to the TV at \(host) on your local network? Next, choose Allow on that TV. Its certificate fingerprint will be saved on this Mac.\n\nSHA-256: \(fingerprint)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Trust and pair")
        alert.addButton(withTitle: "Cancel")
        NSApplication.shared.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
