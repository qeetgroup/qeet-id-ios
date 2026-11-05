import Foundation

/// Why an account couldn't be stored.
enum AccountStoreError: Error, Equatable, Sendable {
    /// The same secret is already on this iPhone.
    case duplicate
    /// The Keychain refused.
    case storage(KeychainError)

    var message: String {
        switch self {
        case .duplicate: String(localized: "This account is already on this iPhone.")
        case .storage: String(localized: "Qeet ID couldn't save to this iPhone's Keychain. Try again.")
        }
    }
}

/// Where accounts live. One item per account: the secret in its value, the rest in its metadata.
protocol AccountStore: Sendable {
    /// Every account, oldest first, read without any secret.
    func accounts() throws(AccountStoreError) -> [OTPAccount]
    /// Stores `draft` as a new account, unless its secret is already here.
    func add(_ draft: AccountDraft, now: Date) throws(AccountStoreError) -> OTPAccount
    /// Saves a changed name, issuer or website list; the secret is untouched.
    func update(_ account: OTPAccount) throws(AccountStoreError)
    /// The secret of one account, to compute its codes.
    func secret(for id: UUID) throws(AccountStoreError) -> Data?
    func delete(_ id: UUID) throws(AccountStoreError)
    func deleteAll() throws(AccountStoreError)
}

/// Accounts in the Keychain, shared with the AutoFill extension through the access group, readable only while the
/// iPhone is unlocked, never synced or backed up.
struct KeychainAccountStore: AccountStore {
    static let service = "com.qeetgroup.qeetid.account"

    private let keychain: Keychain

    init(accessGroup: String? = AppIdentity.keychainGroup) {
        keychain = Keychain(service: Self.service, accessGroup: accessGroup, accessibility: .whenUnlocked)
    }

    func accounts() throws(AccountStoreError) -> [OTPAccount] {
        let items: [Keychain.Item]
        do { items = try keychain.items() } catch { throw .storage(error) }
        let decoder = JSONDecoder()
        return items.compactMap { item in
            guard let generic = item.generic else { return nil }
            return try? decoder.decode(OTPAccount.self, from: generic)
        }
        .sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }
    }

    func add(_ draft: AccountDraft, now: Date) throws(AccountStoreError) -> OTPAccount {
        for existing in try accounts() {
            if try secret(for: existing.id) == draft.secret { throw .duplicate }
        }
        let account = OTPAccount(id: UUID(), issuer: draft.issuer, name: draft.name, parameters: draft.parameters, createdAt: now)
        do {
            try keychain.set(draft.secret, account: account.id.uuidString, generic: try Self.encode(account))
        } catch let error as KeychainError {
            throw .storage(error)
        } catch {
            throw .storage(KeychainError(status: errSecParam))
        }
        return account
    }

    func update(_ account: OTPAccount) throws(AccountStoreError) {
        do {
            try keychain.setGeneric(try Self.encode(account), account: account.id.uuidString)
        } catch let error as KeychainError {
            throw .storage(error)
        } catch {
            throw .storage(KeychainError(status: errSecParam))
        }
    }

    func secret(for id: UUID) throws(AccountStoreError) -> Data? {
        do { return try keychain.value(account: id.uuidString) } catch { throw .storage(error) }
    }

    func delete(_ id: UUID) throws(AccountStoreError) {
        do { try keychain.delete(account: id.uuidString) } catch { throw .storage(error) }
    }

    func deleteAll() throws(AccountStoreError) {
        do { try keychain.deleteAll() } catch { throw .storage(error) }
    }

    private static func encode(_ account: OTPAccount) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(account)
    }
}
