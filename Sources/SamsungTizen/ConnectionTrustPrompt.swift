import UIKit

enum ConnectionTrustPrompt {
    @MainActor static func confirm(host: String, fingerprint: String) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                continuation.resume(returning: true)
                return
            }
            let alert = UIAlertController(
                title: "Trust this Samsung TV?",
                message: "Connect to the TV at \(host) on your local network? Next, choose Allow on that TV. Its certificate fingerprint will be saved on this iPhone.\n\nSHA-256: \(fingerprint)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in continuation.resume(returning: false) })
            alert.addAction(UIAlertAction(title: "Trust and pair", style: .default) { _ in continuation.resume(returning: true) })
            rootVC.present(alert, animated: true)
        }
    }
}
