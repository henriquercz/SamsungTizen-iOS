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

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RemoteView(store: store)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.handleAppForeground()
                    }
                }
        }
    }
}
