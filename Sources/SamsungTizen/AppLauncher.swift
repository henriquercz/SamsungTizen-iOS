import Foundation

enum LaunchMethod: String, CaseIterable {
    case rest = "REST"
    case websocket = "WebSocket"
    case dial = "DIAL"
}

enum LaunchResult: Equatable {
    case confirmed(via: LaunchMethod)
    case unconfirmed(tried: [LaunchMethod])
    case failed(String)
}

@MainActor
struct AppLauncher {
    let host: String
    weak var connection: TizenConnection?
    var order: [LaunchMethod] = [.rest, .websocket, .dial]

    /// Attempt launching the app using fallback strategies and verify actual TV response.
    func launch(_ app: TVApp) async -> LaunchResult {
        guard TizenConnection.localHost(host) else {
            return .failed("Endereço IP da TV inválido.")
        }

        var tried: [LaunchMethod] = []

        // If the catalog has multiple IDs or known aliases, gather candidate IDs
        let candidateIDs = Self.candidateIDs(for: app)

        for method in order {
            tried.append(method)
            switch method {
            case .rest:
                for candidateId in candidateIDs {
                    if await tryRestLaunch(appId: candidateId) {
                        return .confirmed(via: .rest)
                    }
                }

            case .websocket:
                if let connection, connection.isReady {
                    do {
                        for candidateId in candidateIDs {
                            try await connection.launch(candidateId, type: app.type)
                            // Give TV a short moment and check if it started
                            try? await Task.sleep(nanoseconds: 350_000_000)
                            if await verifyRunning(candidateId) {
                                return .confirmed(via: .websocket)
                            }
                        }
                    } catch {
                        // Continue to next method
                    }
                }

            case .dial:
                if let dialName = Self.dialName(for: app) {
                    if await tryRestLaunch(appId: dialName) {
                        return .confirmed(via: .dial)
                    }
                }
            }
        }

        // Final verification check across all candidate IDs
        for candidateId in candidateIDs {
            if await verifyRunning(candidateId) {
                return .confirmed(via: tried.first ?? .rest)
            }
        }

        return .unconfirmed(tried: tried)
    }

    /// POST /api/v2/applications/<appId>
    private func tryRestLaunch(appId: String) async -> Bool {
        guard let encoded = appId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "http://\(host):8001/api/v2/applications/\(encoded)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...204).contains(http.statusCode) {
                return true
            }
        } catch {
            return false
        }
        return false
    }

    /// Check GET /api/v2/applications/<appId> to confirm running state
    func verifyRunning(_ appId: String) async -> Bool {
        guard let encoded = appId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "http://\(host):8001/api/v2/applications/\(encoded)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let running = json["running"] as? Bool ?? false
                let visible = json["visible"] as? Bool ?? false
                return running || visible
            }
        } catch {
            return false
        }
        return false
    }

    /// Resolves DIAL names for well-known streaming apps
    nonisolated static func dialName(for app: TVApp) -> String? {
        let title = app.title.lowercased()
        if title.contains("youtube") { return "YouTube" }
        if title.contains("netflix") { return "Netflix" }
        if title.contains("prime") { return "AmazonInstantVideo" }
        return nil
    }

    /// Candidate IDs from catalog or app object
    nonisolated static func candidateIDs(for app: TVApp) -> [String] {
        var ids = [app.id]
        if let matched = AppCatalog.match(title: app.title, id: app.id), let catalogIds = matched.ids {
            for cid in catalogIds where !ids.contains(cid) {
                ids.append(cid)
            }
        }
        return ids
    }
}
