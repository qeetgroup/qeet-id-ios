import Foundation
import Security

/// A failed Keychain call: its `OSStatus`, never the data it was handling.
struct KeychainError: Error, Equatable, CustomStringConvertible {
    let status: OSStatus

    var description: String {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
        return "Keychain error \(status) (\(message))"
    }
}

/// One generic-password service in the Keychain, in the access group the app shares with its AutoFill extension.
///
/// Every item is written `…ThisDeviceOnly` and not synchronizable, so it never reaches iCloud Keychain, an iCloud or
/// computer backup, or another iPhone. An item keeps its value (the secret) apart from `generic`, a small blob of
/// metadata that can be listed without reading any secret.
struct Keychain: Sendable {
    /// When an item can be read.
    enum Accessibility: Sendable {
        /// While the iPhone is unlocked: a code's secret.
        case whenUnlocked
        /// From the first unlock after a restart: the device link, so a token refresh can run in the background.
        case afterFirstUnlock

        var value: CFString {
            switch self {
            case .whenUnlocked: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            case .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            }
        }
    }

    /// An item as read back: its account name, its metadata and, when asked for, its value.
    struct Item: Sendable {
        let account: String
        let generic: Data?
        let value: Data?
    }

    let service: String
    /// The shared access group, or `nil` for the app's default group.
    let accessGroup: String?
    let accessibility: Accessibility

    /// Adds or replaces the item named `account`.
    func set(_ value: Data, account: String, generic: Data? = nil) throws(KeychainError) {
        var attributes: [CFString: Any] = [
            kSecValueData: value,
            kSecAttrAccessible: accessibility.value,
        ]
        if let generic { attributes[kSecAttrGeneric] = generic }
        let status = SecItemUpdate(query(account: account) as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var item = query(account: account)
            item.merge(attributes) { _, new in new }
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        default:
            throw KeychainError(status: status)
        }
    }

    /// Replaces only the metadata of the item named `account`, leaving its value as it is.
    func setGeneric(_ generic: Data, account: String) throws(KeychainError) {
        let status = SecItemUpdate(query(account: account) as CFDictionary, [kSecAttrGeneric: generic] as CFDictionary)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    /// The value of the item named `account`, or `nil` when there is none.
    func value(account: String) throws(KeychainError) -> Data? {
        var request = query(account: account)
        request[kSecReturnData] = true
        request[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError(status: status)
        }
    }

    /// Every item of the service, with its metadata but without its value: listing reads no secret.
    func items() throws(KeychainError) -> [Item] {
        var request = baseQuery()
        request[kSecReturnAttributes] = true
        request[kSecMatchLimit] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            // Bridged from CFDictionary, the keys arrive as Strings.
            let rows = result as? [[String: Any]] ?? []
            return rows.compactMap { row in
                guard let account = row[kSecAttrAccount as String] as? String else { return nil }
                return Item(account: account, generic: row[kSecAttrGeneric as String] as? Data, value: nil)
            }
        case errSecItemNotFound:
            return []
        default:
            throw KeychainError(status: status)
        }
    }

    /// Deletes the item named `account`; deleting one that isn't there succeeds.
    func delete(account: String) throws(KeychainError) {
        let status = SecItemDelete(query(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    /// Deletes every item of the service.
    func deleteAll() throws(KeychainError) {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private func baseQuery() -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrSynchronizable: false,
            kSecUseDataProtectionKeychain: true,
        ]
        if let accessGroup { query[kSecAttrAccessGroup] = accessGroup }
        return query
    }

    private func query(account: String) -> [CFString: Any] {
        var query = baseQuery()
        query[kSecAttrAccount] = account
        return query
    }
}
