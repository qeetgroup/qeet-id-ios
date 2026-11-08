import Foundation
import Observation

/// AutoFill's list: the accounts for the asking site, the rest, and whether the person has proved it's them yet.
@MainActor
@Observable
final class CodePickerModel {
    enum Access: Equatable {
        case checking
        case unlocked
        case refused
    }

    let site: String
    private(set) var matching: [OTPAccount] = []
    private(set) var others: [OTPAccount] = []
    private(set) var access: Access = .checking
    /// Accounts for other sites the person opened, to see and fill their codes.
    var expanded: Set<UUID> = []

    @ObservationIgnored var onChoose: (@MainActor (OTPAccount, String) -> Void)?
    @ObservationIgnored var onCancel: (@MainActor () -> Void)?
    @ObservationIgnored private let codeBook: CodeBook
    @ObservationIgnored private let authenticator: any DeviceOwnerAuthenticating

    /// - Parameter only: the account chosen in the bar above the keyboard, filled as soon as it's unlocked.
    init(
        store: any AccountStore, site: String, only: OTPAccount? = nil,
        authenticator: any DeviceOwnerAuthenticating = LocalDeviceOwnerAuthenticator()
    ) {
        self.site = site
        self.authenticator = authenticator
        codeBook = CodeBook(store: store)
        if let only {
            matching = [only]
            pendingFill = only
        } else {
            let accounts = (try? store.accounts()) ?? []
            (matching, others) = ServiceMatcher.partition(accounts, for: site)
        }
    }

    @ObservationIgnored private var pendingFill: OTPAccount?

    var isEmpty: Bool { matching.isEmpty && others.isEmpty }

    /// Face ID, Touch ID or the passcode, for the Unlock button's icon.
    var biometry: Biometry { authenticator.biometry() }

    /// Face ID, Touch ID or the passcode, before any code is shown or filled.
    func unlock() async {
        access = .checking
        let outcome = await authenticator.authenticate(reason: String(localized: "Fill a sign-in code from Qeet ID."))
        access = outcome == .success ? .unlocked : .refused
        if access == .unlocked, let account = pendingFill, let code = code(for: account, at: Date()) {
            pendingFill = nil
            onChoose?(account, code.code)
        }
    }

    func code(for account: OTPAccount, at date: Date) -> GeneratedCode? {
        guard access == .unlocked else { return nil }
        return codeBook.code(for: account, at: date)
    }

    func choose(_ account: OTPAccount) {
        guard access == .unlocked, let code = code(for: account, at: Date()) else { return }
        onChoose?(account, code.code)
    }

    func cancel() {
        onCancel?()
    }
}
