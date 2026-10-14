import Foundation

enum AppResources {
    static let bundle: Bundle = {
        if Bundle.main.url(forResource: "app-catalog", withExtension: "json") != nil {
            return Bundle.main
        }
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }()
}
