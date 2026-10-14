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
                title: "Autorizar Conexão na TV",
                message: "Uma solicitação de pareamento foi enviada para sua TV Samsung no endereço \(host). Por favor, selecione 'Permitir' na tela da TV com o controle remoto físico.\n\nImpressão digital SHA-256: \(fingerprint)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in continuation.resume(returning: false) })
            alert.addAction(UIAlertAction(title: "Entendi / Aguardando confirmação", style: .default) { _ in continuation.resume(returning: true) })
            rootVC.present(alert, animated: true)
        }
    }
}
