import AppKit

struct App: Codable, Equatable {
    let name: String
    let bundleID: String?
    let path: String

    init(url: URL) {
        name = url.deletingPathExtension().lastPathComponent
        bundleID = Bundle(url: url)?.bundleIdentifier
        path = url.path
    }

    var label: String { bundleID.map { "\(name) (\($0))" } ?? name }
}

struct InstalledApp {
    let app: App
    let schemes: [String]
}

/// No public API lists all URL schemes, so read them from the Info.plist of installed apps.
func installedApps() -> [InstalledApp] {
    let roots = [
        "/Applications", "\(NSHomeDirectory())/Applications",
        "/System/Applications", "/System/Library/CoreServices",
    ]
    let maxDepth = 3
    var found: [InstalledApp] = []
    for root in roots {
        guard let walker = FileManager.default.enumerator(
            at: URL(fileURLWithPath: root), includingPropertiesForKeys: nil,
            options: [.skipsPackageDescendants, .skipsHiddenFiles])
        else { continue }
        for case let url as URL in walker {
            if walker.level >= maxDepth { walker.skipDescendants() }
            guard url.pathExtension == "app" else { continue }
            let types = Bundle(url: url)?.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] ?? []
            let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }.map { $0.lowercased() }
            found.append(InstalledApp(app: App(url: url), schemes: Array(Set(schemes)).sorted()))
        }
    }
    return found.sorted { $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending }
}

// MARK: - Lookup

private func probeURL(_ scheme: String) -> URL? { URL(string: "\(scheme)://") }

func defaultApp(for target: Target) -> App? {
    let workspace = NSWorkspace.shared
    switch target {
    case .scheme(let name): return probeURL(name).flatMap { workspace.urlForApplication(toOpen: $0) }.map(App.init)
    case .type(let type): return workspace.urlForApplication(toOpen: type).map(App.init)
    }
}

/// Several copies of one app (same name and bundle ID) show once.
func allApps(for target: Target) -> [App] {
    let workspace = NSWorkspace.shared
    let urls: [URL]
    switch target {
    case .scheme(let name): urls = probeURL(name).map { workspace.urlsForApplications(toOpen: $0) } ?? []
    case .type(let type): urls = workspace.urlsForApplications(toOpen: type)
    }
    var seen = Set<String>()
    return urls.map(App.init).filter { seen.insert($0.label).inserted }
}

// MARK: - Set

func setDefault(appURL: URL, for target: Target) async throws {
    switch target {
    case .scheme(let name): try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: name)
    case .type(let type): try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: type)
    }
}

// MARK: - App resolution

struct AppResolveError: Error, CustomStringConvertible {
    let description: String
}

func matchByName(_ query: String, in apps: [App]) -> [App] {
    apps.filter { $0.name.caseInsensitiveCompare(query) == .orderedSame }
}

/// Accepts a path to a .app, a bundle ID, or an app name.
func resolveApp(_ query: String) throws -> URL {
    let path = (query as NSString).expandingTildeInPath
    if path.hasSuffix(".app"), FileManager.default.fileExists(atPath: path) {
        return URL(fileURLWithPath: path)
    }
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: query) {
        return url
    }
    let matches = matchByName(query, in: installedApps().map(\.app))
    switch matches.count {
    case 1: return URL(fileURLWithPath: matches[0].path)
    case 0: throw AppResolveError(description: "app '\(query)' not found; use a bundle ID, app name, or .app path")
    default:
        let list = matches.map { "  \($0.path)" }.joined(separator: "\n")
        throw AppResolveError(description: "app name '\(query)' is ambiguous; use a path or bundle ID:\n\(list)")
    }
}
