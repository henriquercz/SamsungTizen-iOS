import SwiftUI
import UIKit

struct CatalogApp: Codable {
    let title: String
    let icon: String?
    let aliases: [String]?
    /// Samsung app IDs, newest first. The first one is launched when the TV cannot list its apps.
    let ids: [String]?
    /// 4 for native Tizen apps; store apps (2) open through a deep link.
    let type: Int?
}

/// Bundled tiles for well-known apps, matched by the name the TV reports. Tizen 5 and later
/// no longer list installed apps, so the IDs here also stand in for that list.
enum AppCatalog {
    static let entries: [CatalogApp] = {
        guard let url = AppResources.bundle.url(forResource: "app-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([CatalogApp].self, from: data)) ?? []
    }()
    static func normalized(_ title: String) -> String {
        title.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }
    static func match(title: String, id: String = "") -> CatalogApp? {
        let name = normalized(title)
        return entries.first { entry in
            entry.ids?.contains(id) == true || (entry.aliases ?? [entry.title]).contains { normalized($0) == name }
        }
    }
}

/// Bundled tiles first, then icons the TV sent, cached under Application Support.
enum AppIcons {
    static let cacheDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("br.local.TizenRemote").appendingPathComponent("icons")
    static func cacheFile(for appID: String) -> URL {
        let safe = String(appID.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-" ? Character($0) : "_" })
        return cacheDirectory.appendingPathComponent(safe + ".img")
    }
    static func url(for app: TVApp) -> URL? {
        if let icon = app.icon, let bundled = AppResources.bundle.url(forResource: icon, withExtension: nil, subdirectory: "AppAssets") { return bundled }
        let cached = cacheFile(for: app.id)
        return FileManager.default.fileExists(atPath: cached.path) ? cached : nil
    }
}

struct BrandTheme {
    static let samsungBlue = Color(red: 0.25, green: 0.43, blue: 1)
    let color: Color
    let label: String
    let tagline: String
    @MainActor private static var logoColors: [String: Color] = [:]
    
    // ponytail: default to samsungBlue or cached brand accents without heavy pixel processing
    @MainActor static func logoColor(_ url: URL) -> Color {
        if let known = logoColors[url.path] { return known }
        let result = samsungBlue
        logoColors[url.path] = result
        return result
    }
    
    @MainActor static func forApp(_ id: String, title: String = "", icon: URL? = nil) -> BrandTheme {
        let key = (id + " " + title).lowercased()
        if key.contains("ps5") || key.contains("playstation") { return .init(color: Color(red: 0.12, green: 0.43, blue: 1), label: "PlayStation 5", tagline: "Sua próxima aventura começa aqui.") }
        if key.contains("netflix") { return .init(color: Color(red: 0.94, green: 0.08, blue: 0.13), label: "Netflix", tagline: "Uma grande história está esperando por você.") }
        if key.contains("youtube") { return .init(color: Color(red: 1, green: 0.18, blue: 0.23), label: "YouTube", tagline: "Tudo o que você ama, na tela grande.") }
        if key.contains("amazon") || key.contains("prime") { return .init(color: Color(red: 0.08, green: 0.64, blue: 1), label: "Prime Video", tagline: "Hora da pipoca.") }
        if key.contains("disney") { return .init(color: Color(red: 0.20, green: 0.38, blue: 1), label: "Disney+", tagline: "Um universo de histórias.") }
        if key.contains("spotify") { return .init(color: Color(red: 0.12, green: 0.84, blue: 0.43), label: "Spotify", tagline: "Crie o clima. Aperte o play.") }
        if key.contains("twitch") { return .init(color: Color(red: 0.61, green: 0.35, blue: 1), label: "Twitch", tagline: "Sua comunidade, ao vivo.") }
        if key.contains("hbo") || key.contains(" max") { return .init(color: Color(red: 0.60, green: 0.34, blue: 1), label: title.isEmpty ? "Max" : title, tagline: "Grandes histórias. Momentos inesquecíveis.") }
        if key.contains("globo") { return .init(color: Color(red: 1, green: 0.33, blue: 0.23), label: title, tagline: "Seu entretenimento, do seu jeito.") }
        if key.contains("apple") { return .init(color: Color(white: 0.9), label: title, tagline: "O cinema na sua sala de estar.") }
        if key.contains("chromecast") { return .init(color: Color(red: 0.28, green: 0.66, blue: 0.93), label: "Chromecast", tagline: "Do seu iPhone para a sua TV.") }
        return .init(color: icon.map(logoColor) ?? samsungBlue, label: title, tagline: "Sua Samsung. Sua sala. Seu controle.")
    }
}
