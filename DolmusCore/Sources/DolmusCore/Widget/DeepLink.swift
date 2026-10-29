import Foundation

/// Uygulamanın kendi adresleri (`izmirdolmus://…`). Widget'lar ve kontroller
/// uygulamayı bunlarla belli bir yerde açar; widget adresi kurar, uygulama çözer.
public enum DeepLink: Equatable, Sendable {
    /// Ev ↔ İş tarifi, haritada.
    case commute(CommuteDirection)
    /// Hat detayı.
    case hat(id: String)
    /// "Nereden → Nereye".
    case tripPlanner
    /// "Nereden → Nereye", varış Ev.
    case goHome
    /// Ayarlar (Ev ve İş adresleri orada).
    case settings

    public static let scheme = "izmirdolmus"

    /// Adresi çözer; şema ya da biçim tanınmıyorsa `nil`.
    public init?(url: URL) {
        guard url.scheme == Self.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        let query = { (name: String) in components.queryItems?.first { $0.name == name }?.value }
        switch components.host {
        case "trip":
            guard let direction = query("direction").flatMap(CommuteDirection.init(rawValue:)) else { return nil }
            self = .commute(direction)
        case "hat":
            // Hat kimliğinde "#" olabilir ("M35#toki"); yolda kodlanmış gelir.
            guard let id = url.pathComponents.dropFirst().first, !id.isEmpty else { return nil }
            self = .hat(id: id)
        case "plan":
            self = query("to") == "home" ? .goHome : .tripPlanner
        case "settings":
            self = .settings
        default:
            return nil
        }
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .commute(let direction):
            components.host = "trip"
            components.queryItems = [URLQueryItem(name: "direction", value: direction.rawValue)]
        case .hat(let id):
            components.host = "hat"
            components.percentEncodedPath = "/" + (id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["#", "/"])) ?? id)
        case .tripPlanner:
            components.host = "plan"
        case .goHome:
            components.host = "plan"
            components.queryItems = [URLQueryItem(name: "to", value: "home")]
        case .settings:
            components.host = "settings"
        }
        return components.url!
    }
}
