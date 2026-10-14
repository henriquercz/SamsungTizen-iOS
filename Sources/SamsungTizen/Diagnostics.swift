import SwiftUI
import UIKit

struct DiagnosticEntry: Identifiable {
    let id = UUID()
    let date: Date
    let area: String
    let detail: String
}

/// In-memory ring buffer of what the TV and the touch screen did, so a failure on the phone can be read without a Mac.
@MainActor final class Diagnostics: ObservableObject {
    static let shared = Diagnostics()
    static let limit = 300
    @Published private(set) var entries: [DiagnosticEntry] = []

    func record(_ area: String, _ detail: String) {
        entries.insert(DiagnosticEntry(date: Date(), area: area, detail: Self.redact(detail)), at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
    }
    func clear() { entries.removeAll() }
    func exportText() -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss.SSS"
        return entries.reversed().map { "\(formatter.string(from: $0.date)) [\($0.area)] \($0.detail)" }.joined(separator: "\n")
    }
    /// Pairing tokens never leave the phone, not even in a shared log.
    nonisolated static func redact(_ text: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: "(?i)(token[\"']?\\s*[=:]\\s*[\"']?)[^&\"'\\s,}]+") else { return text }
        return expression.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$1•••")
    }
}

/// Logs every touch that reaches the app window, without ever claiming one. Used to learn what AssistiveTouch sends.
struct TouchProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeAnchor { ProbeAnchor() }
    func updateUIView(_ view: ProbeAnchor, context: Context) {}

    final class ProbeAnchor: UIView {
        private let recognizer = ProbeRecognizer()
        override func didMoveToWindow() {
            super.didMoveToWindow()
            recognizer.view?.removeGestureRecognizer(recognizer)
            guard let window else { return }
            window.addGestureRecognizer(recognizer)
            Diagnostics.shared.record("Toque", "Sonda ligada · AssistiveTouch ativo: \(UIAccessibility.isAssistiveTouchRunning)")
        }
        override func removeFromSuperview() {
            recognizer.view?.removeGestureRecognizer(recognizer)
            super.removeFromSuperview()
        }
    }

    final class ProbeRecognizer: UIGestureRecognizer {
        private var moves = 0
        override init(target: Any?, action: Selector?) {
            super.init(target: target, action: action)
            cancelsTouchesInView = false; delaysTouchesBegan = false; delaysTouchesEnded = false
        }
        convenience init() { self.init(target: nil, action: nil) }
        private func log(_ phase: String, _ touches: Set<UITouch>) {
            guard let touch = touches.first, let window = view else { return }
            let point = touch.location(in: window)
            let size = window.bounds.size
            Diagnostics.shared.record("Toque", "\(phase) x=\(Int(point.x))/\(Int(size.width)) y=\(Int(point.y))/\(Int(size.height)) toques=\(touches.count)")
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { moves = 0; log("início", touches) }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { moves += 1; if moves == 1 { log("arrasto", touches) } }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { log("fim (\(moves) mov.)", touches) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { log("cancelado", touches) }
        // Never leaves .possible, so it can never take a touch away from a button.
        override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        override func shouldRequireFailure(of otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        override func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    }
}

/// Settings card: read-only facts about the connection, the touch probe switch and the shareable log.
struct DiagnosticsCard: View {
    @ObservedObject var store: RemoteStore
    @ObservedObject private var log = Diagnostics.shared
    @AppStorage("touchProbe") private var touchProbe = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diagnóstico").font(.system(size: 14, weight: .bold))
            Text("\(store.system.isEmpty ? "TV desconhecida" : store.system) · \(store.model.isEmpty ? "modelo ?" : store.model) · firmware \(store.firmware.isEmpty ? "?" : store.firmware)")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            Text("Conectado: \(store.connected ? "sim" : "não") · Volume por rede: \(store.hasVolume ? "sim" : "não") · Eventos: \(log.entries.count)")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            Toggle("Registrar toques (AssistiveTouch)", isOn: $touchProbe).font(.system(size: 12, weight: .medium))
            HStack(spacing: 10) {
                ShareLink(item: log.exportText()) { Label("Compartilhar log", systemImage: "square.and.arrow.up") }
                Spacer()
                Button("Limpar") { log.clear() }.foregroundStyle(.red)
            }
            .font(.system(size: 12, weight: .semibold))
            ForEach(log.entries.prefix(12)) { entry in
                Text("[\(entry.area)] \(entry.detail)")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.5)).lineLimit(2)
            }
        }
    }
}
