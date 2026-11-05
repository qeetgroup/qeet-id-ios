import Observation
import Qeetrix
import SwiftUI

/// What covers the app: nothing, the Locked screen, or the privacy cover the app switcher shows.
enum Shield: Equatable {
    case none
    case locked
    case privacy
}

/// A screen that covers the whole app.
enum AppModal: Identifiable, Equatable {
    /// Screens 6 to 8: scan a QR code or type a setup key.
    case addAccount
    /// Screen 12: scan the pairing code.
    case scanPairing
    /// Screens 16 to 20: a sign-in request.
    case signInRequest(UUID)

    var id: String {
        switch self {
        case .addAccount: "add-account"
        case .scanPairing: "scan-pairing"
        case .signInRequest(let id): "sign-in-\(id.uuidString)"
        }
    }
}

/// The screens pushed onto the accounts list.
enum Route: Hashable {
    case settings
    /// Screen 25, AutoFill codes (iOS 18 and later).
    case autoFill
    /// Screen 11, Link this iPhone.
    case linkIntro
    /// Screen 13: name and link, with the scanned code, or `nil` to type it.
    case linkName(code: String?)
    /// Screen 14, iPhone linked.
    case linked
}

/// The app's state across screens: the person's choices, the lock, the accounts, the link, what covers the app,
/// navigation and the toast.
@MainActor
@Observable
final class AppModel {
    let preferences: Preferences
    let lock: AppLock
    let accounts: AccountsModel
    let link: LinkModel
    let network = NetworkMonitor()
    /// Whether notifications can reach this iPhone, for "Sign-in requests are off".
    private(set) var notifications: NotificationPermission = .allowed
    /// The toast hosted at the root, over every screen.
    var toast: QeetrixToast?
    /// The screens pushed onto Accounts.
    var path: [Route] = []
    /// The full-screen cover, if any.
    var modal: AppModal?

    private(set) var scenePhase: ScenePhase = .active
    /// Returning from the background — not from a Face ID prompt or Control Center — asks to unlock and checks for
    /// waiting requests.
    @ObservationIgnored private var wasInBackground = true
    /// A request to open once the app is unlocked.
    @ObservationIgnored private var queuedRequest: (id: UUID, prefetched: FetchedChallenge?)?
    @ObservationIgnored private var requestModels: [UUID: SignInRequestModel] = [:]
    @ObservationIgnored private var lastPendingCheck: Date?

    init(
        preferences: Preferences, authenticator: any DeviceOwnerAuthenticating, accountStore: any AccountStore,
        linkStore: DeviceLinkStore = DeviceLinkStore()
    ) {
        self.preferences = preferences
        lock = AppLock(preferences: preferences, authenticator: authenticator)
        accounts = AccountsModel(store: accountStore)
        link = LinkModel(store: linkStore, push: PushRegistrar())
        link.push.onTokenChange = { [weak self] token in
            guard let self else { return }
            Task { await self.link.pushTokenChanged(token) }
        }
    }

    /// The app as it runs on an iPhone: the Keychain, the system's Face ID, the production API.
    static func live() -> AppModel {
        #if DEBUG
            APIEnvironment.applyLaunchArguments()
            if UITestSupport.isActive { return UITestSupport.makeModel() }
        #endif
        return AppModel(
            preferences: Preferences(), authenticator: LocalDeviceOwnerAuthenticator(), accountStore: KeychainAccountStore())
    }

    /// Loads what's stored and starts watching the network. Called once, at launch.
    func start() {
        if lock.isLocked { accounts.suspend() }
        accounts.load()
        link.load()
        network.start()
        if link.isLinked { link.push.register() }
    }

    /// What covers the app now. The privacy cover shows whenever the app isn't active — the app switcher, Notification
    /// Center — except while the app's own Face ID or permission prompt is up.
    var shield: Shield {
        if lock.isLocked { return .locked }
        if scenePhase != .active && !lock.isAuthenticating { return .privacy }
        return .none
    }

    func scenePhaseChanged(to phase: ScenePhase) {
        scenePhase = phase
        switch phase {
        case .background:
            wasInBackground = true
            lock.lock()
            accounts.suspend()
            endEditing()
        case .active:
            if wasInBackground {
                wasInBackground = false
                accounts.load()
                link.load()
                Task { await refreshNotificationPermission() }
                if lock.isLocked {
                    Task { await lock.unlock() }
                } else {
                    accounts.resume()
                    Task { await checkPendingRequests() }
                }
            }
        default:
            break
        }
    }

    /// The app was unlocked: open a request that arrived meanwhile, or look for one.
    func didUnlock() {
        accounts.resume()
        if let queued = queuedRequest {
            queuedRequest = nil
            openSignInRequest(queued.id, prefetched: queued.prefetched)
        } else {
            Task { await checkPendingRequests() }
        }
    }

    func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
    }

    /// An account was added: say so.
    func accountAdded(_ account: OTPAccount) {
        toast = QeetrixToast(.success, title: String(localized: "\(account.issuer) added"))
    }

    // MARK: - Linking

    /// A pairing code was scanned in Add account or opened from a `qeetidauth://pair` link: show it on Name this
    /// iPhone, where linking waits for the person's tap.
    func startLinking(code: String) {
        modal = nil
        showLinking(code: code)
    }

    func showLinking(code: String?) {
        guard preferences.hasCompletedOnboarding else { return }
        path = [.linkIntro, .linkName(code: code)]
    }

    /// Opens a URL the app was given: only `qeetidauth://pair?code=…`.
    func open(_ url: URL) {
        guard let code = PairingCode.fromLink(url) else { return }
        startLinking(code: code)
    }

    // MARK: - Sign-in requests

    /// Opens a sign-in request, from a notification or the pending check. While locked, it waits for the unlock.
    func openSignInRequest(_ id: UUID, prefetched: FetchedChallenge? = nil) {
        guard preferences.hasCompletedOnboarding else { return }
        if lock.isLocked {
            queuedRequest = (id, prefetched)
            return
        }
        if modal == .signInRequest(id) { return }
        requestModels[id] = SignInRequestModel(id: id, prefetched: prefetched, link: link, lock: lock)
        modal = .signInRequest(id)
    }

    /// The model of an open request, for its screen.
    func requestModel(for id: UUID) -> SignInRequestModel {
        if let model = requestModels[id] { return model }
        let model = SignInRequestModel(id: id, link: link, lock: lock)
        requestModels[id] = model
        return model
    }

    func closeSignInRequest() {
        if case .signInRequest(let id) = modal { requestModels[id] = nil }
        modal = nil
    }

    /// Asks the server for requests waiting for this iPhone and opens the newest, as a notification tap would. The
    /// path that works without push, on a simulator and against a local server.
    func checkPendingRequests(force: Bool = false) async {
        guard link.isLinked, !lock.isLocked else { return }
        if case .signInRequest = modal { return }
        if !force, let last = lastPendingCheck, Date().timeIntervalSince(last) < 2 { return }
        lastPendingCheck = Date()
        let pending = await link.pendingRequests()
        guard let newest = pending.first(where: { $0.isOpen(at: Date()) }) else { return }
        openSignInRequest(newest.challenge.id, prefetched: newest)
    }

    func refreshNotificationPermission() async {
        notifications = await NotificationPermission.current()
    }

    /// Hides the keyboard, so it doesn't stay up over the Locked screen.
    private func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
