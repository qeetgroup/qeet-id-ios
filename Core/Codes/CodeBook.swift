import CryptoKit
import Foundation

/// A code as shown: its digits and when it is valid. Holds no secret.
struct GeneratedCode: Equatable, Sendable {
    let code: String
    let validity: ClosedRange<Date>
}

/// Makes codes. It reads each account's secret from the store the first time it is needed and keeps it as a CryptoKit
/// key in memory, never in a view's state, until `forgetAll()` (on lock) or `forget(_:)` (on delete).
@MainActor
final class CodeBook {
    private let store: any AccountStore
    private var keys: [UUID: SymmetricKey] = [:]

    init(store: any AccountStore) {
        self.store = store
    }

    /// The code `account` shows at `date`, or `nil` when its secret can't be read (the iPhone is locked).
    func code(for account: OTPAccount, at date: Date) -> GeneratedCode? {
        guard let key = key(for: account.id) else { return nil }
        return GeneratedCode(
            code: TOTP.code(key: key, at: date, parameters: account.parameters),
            validity: TOTP.validity(at: date, period: account.parameters.period))
    }

    func forget(_ id: UUID) {
        keys[id] = nil
    }

    func forgetAll() {
        keys.removeAll()
    }

    private func key(for id: UUID) -> SymmetricKey? {
        if let key = keys[id] { return key }
        guard let secret = try? store.secret(for: id) else { return nil }
        let key = SymmetricKey(data: secret)
        keys[id] = key
        return key
    }
}
