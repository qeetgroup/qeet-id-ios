import Foundation

/// Which accounts belong to the site asking AutoFill for a code, to list them first.
///
/// An account belongs to a site for sure once the person chose it there (`OTPAccount.websites`); before that, only by
/// its issuer's name matching a label of the site's host ("GitHub" and `github.com`). A match orders the list; it never
/// fills on its own.
enum ServiceMatcher {
    /// The host in a service identifier, lowercased and without `www.`: `github.com` from `https://www.github.com/login`.
    static func host(from identifier: String) -> String {
        var text = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let url = URL(string: text), let host = url.host, url.scheme != nil {
            text = host
        }
        if text.hasPrefix("www.") { text.removeFirst(4) }
        while text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// Whether `account` was chosen for `host`, or for a domain `host` is under.
    static func isRemembered(_ account: OTPAccount, for host: String) -> Bool {
        account.websites.contains { site in host == site || host.hasSuffix("." + site) }
    }

    /// Whether the issuer's name matches a label of `host`: "GitHub" → `github.com`, "Zoho Books" → `books.zoho.in`
    /// does not, "Zoho" does.
    static func issuerMatches(_ account: OTPAccount, host: String) -> Bool {
        let issuer = account.issuer.lowercased()
        if issuer.contains("."), host == issuer || host.hasSuffix("." + issuer) { return true }
        let token = issuer.filter { $0.isLetter || $0.isNumber }
        guard token.count >= 2 else { return false }
        let labels = host.split(separator: ".").dropLast().map { $0.filter { $0.isLetter || $0.isNumber } }
        return labels.contains(token)
    }

    /// `accounts` split into those for `host` (remembered first, then by issuer) and the rest, each in its order.
    static func partition(_ accounts: [OTPAccount], for host: String) -> (matching: [OTPAccount], others: [OTPAccount]) {
        guard !host.isEmpty else { return ([], accounts) }
        let remembered = accounts.filter { isRemembered($0, for: host) }
        let byIssuer = accounts.filter { !isRemembered($0, for: host) && issuerMatches($0, host: host) }
        let matching = remembered + byIssuer
        let ids = Set(matching.map(\.id))
        return (matching, accounts.filter { !ids.contains($0.id) })
    }

    /// The site to remember an account for: the host, without `www.`.
    static func siteToRemember(_ host: String) -> String? {
        host.isEmpty || !host.contains(".") ? nil : host
    }
}
