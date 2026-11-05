import Observation
import Qeetrix
import SwiftUI

/// The accounts on this iPhone and their current codes. Codes are recomputed when a period ends; secrets stay in
/// the `CodeBook`, never here.
@MainActor
@Observable
final class AccountsModel {
    private(set) var accounts: [OTPAccount] = []
    /// Each account's code now, by id.
    private(set) var codes: [UUID: GeneratedCode] = [:]
    /// The storage refused: the screen says so.
    private(set) var storageError: AccountStoreError?
    var query = ""

    @ObservationIgnored let store: any AccountStore
    @ObservationIgnored let codeBook: CodeBook
    @ObservationIgnored private let identities: OneTimeCodeIdentities
    @ObservationIgnored private let now: () -> Date

    init(store: any AccountStore, identities: OneTimeCodeIdentities = OneTimeCodeIdentities(), now: @escaping () -> Date = Date.init) {
        self.store = store
        self.identities = identities
        self.now = now
        codeBook = CodeBook(store: store)
    }

    /// The accounts the search keeps: matched on the issuer or the account name.
    var visibleAccounts: [OTPAccount] {
        let query = self.query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return accounts }
        return accounts.filter { $0.issuer.localizedCaseInsensitiveContains(query) || $0.name.localizedCaseInsensitiveContains(query) }
    }

    func load() {
        do {
            accounts = try store.accounts()
            storageError = nil
        } catch {
            storageError = error
            Log.storage.error("Couldn't list the accounts")
        }
        refreshCodes()
        identities.sync(accounts)
    }

    /// Recomputes every code for now.
    func refreshCodes() {
        let date = now()
        var next: [UUID: GeneratedCode] = [:]
        for account in accounts {
            next[account.id] = codeBook.code(for: account, at: date)
        }
        if next != codes { codes = next }
    }

    /// Keeps the codes current until cancelled: wakes when the earliest code ends.
    func runClock() async {
        while !Task.isCancelled {
            refreshCodes()
            let date = now()
            let nextChange = codes.values.map(\.validity.upperBound).min() ?? date.addingTimeInterval(1)
            let wait = min(max(nextChange.timeIntervalSince(date), 0.05), 60)
            try? await Task.sleep(for: .seconds(wait) + .milliseconds(20))
        }
    }

    /// Adds an account from a QR code or a typed key.
    @discardableResult
    func add(_ draft: AccountDraft) throws(AccountStoreError) -> OTPAccount {
        let account = try store.add(draft, now: now())
        load()
        return account
    }

    func rename(_ account: OTPAccount, issuer: String, name: String) {
        var renamed = account
        let issuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        renamed.issuer = issuer.isEmpty ? account.issuer : issuer
        renamed.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try store.update(renamed)
        } catch {
            storageError = error
        }
        load()
    }

    func delete(_ account: OTPAccount) {
        do {
            try store.delete(account.id)
        } catch {
            storageError = error
        }
        codeBook.forget(account.id)
        load()
    }

    /// Forgets the secrets held in memory: the app was locked.
    func forgetSecrets() {
        codeBook.forgetAll()
        codes = [:]
    }
}
