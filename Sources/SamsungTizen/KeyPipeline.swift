import Foundation

/// Serial queue actor for sending remote key strokes without race conditions or reordering.
actor KeyPipeline {
    private let sendAction: (String) async throws -> Void
    private var isProcessing = false
    private var queue: [String] = []

    init(send: @escaping (String) async throws -> Void) {
        self.sendAction = send
    }

    func enqueue(_ key: String) {
        queue.append(key)
        if !isProcessing {
            isProcessing = true
            Task {
                await processQueue()
            }
        }
    }

    private func processQueue() async {
        while !queue.isEmpty {
            let key = queue.removeFirst()
            do {
                try await sendAction(key)
            } catch {
                // If a key fails, we still continue to drain the queue or log error
            }
            // Small inter-key spacing for rapid bursts so Tizen OS hardware registers each event
            try? await Task.sleep(nanoseconds: 40_000_000) // 40ms spacing
        }
        isProcessing = false
    }

    func drained() async {
        while isProcessing || !queue.isEmpty {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
