import Foundation

/// A browser's user agent in a person's words: "Chrome on macOS".
enum UserAgentDescription {
    /// "Chrome on macOS", "Safari on iPhone", "Firefox", "Windows", or `nil` when nothing is recognised.
    static func describe(_ userAgent: String?) -> String? {
        guard let userAgent, !userAgent.isEmpty else { return nil }
        let browser = self.browser(userAgent)
        let system = self.system(userAgent)
        switch (browser, system) {
        case (let browser?, let system?):
            return String(localized: "\(browser) on \(system)", comment: "A browser on a system: Chrome on macOS")
        case (let browser?, nil): return browser
        case (nil, let system?): return system
        case (nil, nil): return nil
        }
    }

    /// The browser, by the tokens browsers send; order matters, since most claim to be Safari and Chrome too.
    static func browser(_ userAgent: String) -> String? {
        let rules: [(token: String, name: String)] = [
            ("Edg/", "Edge"), ("EdgA/", "Edge"), ("EdgiOS/", "Edge"),
            ("OPR/", "Opera"), ("OPiOS/", "Opera"),
            ("SamsungBrowser/", "Samsung Internet"),
            ("Vivaldi/", "Vivaldi"), ("Brave/", "Brave"), ("YaBrowser/", "Yandex Browser"),
            ("Firefox/", "Firefox"), ("FxiOS/", "Firefox"),
            ("CriOS/", "Chrome"), ("Chrome/", "Chrome"), ("Chromium/", "Chromium"),
            ("Safari/", "Safari"),
        ]
        return rules.first { userAgent.contains($0.token) }?.name
    }

    /// The operating system or device.
    static func system(_ userAgent: String) -> String? {
        if userAgent.contains("iPhone") { return "iPhone" }
        if userAgent.contains("iPad") { return "iPad" }
        if userAgent.contains("Android") { return "Android" }
        if userAgent.contains("CrOS") { return "ChromeOS" }
        if userAgent.contains("Windows") { return "Windows" }
        if userAgent.contains("Mac OS X") || userAgent.contains("Macintosh") { return "macOS" }
        if userAgent.contains("Linux") { return "Linux" }
        return nil
    }
}
