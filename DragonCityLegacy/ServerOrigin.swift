import Foundation

/// Navigation origin, not a network firewall or a subresource filter.
struct ServerOrigin: Equatable {
    let scheme: String
    let host: String
    let port: Int

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let scheme = parts.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = parts.host?.lowercased(), !host.isEmpty,
              parts.user == nil, parts.password == nil else {
            return nil
        }

        let port = parts.port ?? (scheme == "https" ? 443 : 80)
        guard (1...65535).contains(port) else { return nil }
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    func allows(_ url: URL) -> Bool {
        ServerOrigin(url: url) == self
    }
}
