import Foundation

/// Where the app's API is. **Production, unless a Debug build was told otherwise**: an unconfigured build talks to
/// `https://api.id.qeet.in`, and Release builds have no other address at all.
enum APIEnvironment {
    static let production = URL(string: "https://api.id.qeet.in")!

    /// The API the app and its extensions call.
    static var baseURL: URL {
        #if DEBUG
            if let override = AppIdentity.sharedDefaults?.string(forKey: overrideKey), let url = Self.validated(override) {
                return url
            }
        #endif
        return production
    }

    #if DEBUG
        /// The App Group key the Debug override is kept under, so the notification extension follows it too.
        static let overrideKey = "debug.apiBaseURL"

        /// Applies `-api-url <url>` from the launch arguments (Debug builds only). `-api-url default` returns to
        /// production. Returns the address now in use.
        @discardableResult
        static func applyLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> URL {
            if let index = arguments.firstIndex(of: "-api-url"), arguments.indices.contains(index + 1) {
                let value = arguments[index + 1]
                if value == "default" {
                    AppIdentity.sharedDefaults?.removeObject(forKey: overrideKey)
                } else if validated(value) != nil {
                    AppIdentity.sharedDefaults?.set(value, forKey: overrideKey)
                }
            }
            return baseURL
        }
    #endif

    /// `text` as an API address: http or https, with a host, and no path, query or credentials.
    static func validated(_ text: String) -> URL? {
        guard let components = URLComponents(string: text), let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http", let host = components.host, !host.isEmpty,
            components.user == nil, components.password == nil, components.query == nil,
            components.path.isEmpty || components.path == "/"
        else { return nil }
        var clean = components
        clean.path = ""
        return clean.url
    }
}
