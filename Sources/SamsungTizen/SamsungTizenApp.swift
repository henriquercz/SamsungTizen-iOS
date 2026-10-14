import SwiftUI

@main
struct SamsungTizenApp: App {
    @StateObject private var store = RemoteStore()

    init() {
        if CommandLine.arguments.contains("--self-check") {
            Task {
                do {
                    try await FeatureChecks.run()
                    exit(0)
                } catch {
                    print("FAIL: \(error)")
                    exit(1)
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RemoteView(store: store)
                .preferredColorScheme(.dark)
        }
    }
}
