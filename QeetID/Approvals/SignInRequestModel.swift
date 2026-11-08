import Foundation
import Observation
import Qeetrix
import SwiftUI

/// One sign-in request, from loading it to its outcome. Approving needs the 2-digit number from the sign-in screen and
/// a fresh Face ID (or passcode) check; denying needs neither.
@MainActor
@Observable
final class SignInRequestModel {
    enum Phase: Equatable {
        case loading
        case review(FetchedChallenge)
        case outcome(Outcome)
        case failedToLoad(APIError)
    }

    enum Outcome: Equatable {
        /// Screen 18: the computer finishes signing in by itself.
        case approved(browser: String?)
        /// Screen 19: nobody got in, but whoever tried knows the password.
        case denied
        /// Screen 20: nothing was approved.
        case ended(EndReason)
    }

    enum EndReason: Equatable {
        case numberMismatch
        case expired
        case answered
        case notFound
        case notLinked
    }

    let id: UUID
    private(set) var phase: Phase = .loading
    /// The request as last read, to name the sign-in on its outcome (browser, place, time).
    private(set) var request: SignInChallenge?
    /// The number as typed. Not a secret: it's on the sign-in screen.
    var number = "" {
        didSet { if number != oldValue { numberError = nil } }
    }
    private(set) var numberError: String?
    private(set) var isApproving = false
    private(set) var isDenying = false
    /// A problem to tell the person while the request stays open: no connection, no passcode.
    var alert: QeetrixAlertDialog?

    @ObservationIgnored private let link: LinkModel
    @ObservationIgnored private let lock: AppLock
    @ObservationIgnored private let client: @MainActor () -> APIClient

    init(
        id: UUID, prefetched: FetchedChallenge? = nil, link: LinkModel, lock: AppLock,
        client: @escaping @MainActor () -> APIClient = { APIClient() }
    ) {
        self.id = id
        self.link = link
        self.lock = lock
        self.client = client
        if let prefetched {
            request = prefetched.challenge
            phase = Self.phase(for: prefetched, isLinked: link.isLinked)
        }
    }

    /// The account the request is for, as the link names it.
    var accountEmail: String? { link.summary?.accountEmail }

    /// Reads the request from the server.
    func load() async {
        if case .review = phase { return }
        if case .outcome = phase { return }
        phase = .loading
        do {
            let fetched = try await client().challenge(id)
            request = fetched.challenge
            phase = Self.phase(for: fetched, isLinked: link.isLinked)
        } catch .notFound {
            phase = .outcome(.ended(.notFound))
        } catch {
            phase = .failedToLoad(error)
        }
    }

    static func phase(for fetched: FetchedChallenge, isLinked: Bool) -> Phase {
        switch fetched.challenge.status {
        case .pending:
            guard isLinked else { return .outcome(.ended(.notLinked)) }
            return fetched.isOpen(at: Date()) ? .review(fetched) : .outcome(.ended(.expired))
        case .expired: return .outcome(.ended(.expired))
        case .approved, .denied: return .outcome(.ended(.answered))
        case .unknown: return .outcome(.ended(.notFound))
        }
    }

    /// Seconds left to answer, by this iPhone's clock corrected to the server's.
    func secondsLeft(at date: Date) -> Int {
        guard case .review(let fetched) = phase else { return 0 }
        return max(0, Int(fetched.expiresAtLocal.timeIntervalSince(date).rounded(.up)))
    }

    /// The two minutes ran out while the screen was open.
    func expireIfDue(at date: Date = Date()) {
        guard case .review(let fetched) = phase, date >= fetched.expiresAtLocal, !isApproving, !isDenying else { return }
        phase = .outcome(.ended(.expired))
    }

    func approve() async {
        guard case .review(let fetched) = phase, !isApproving, !isDenying else { return }
        guard number.count == 2, let value = Int(number) else {
            numberError = String(localized: "Type the 2-digit number shown on your sign-in screen.")
            return
        }
        isApproving = true
        defer { isApproving = false }
        let reason =
            switch (fetched.challenge.context.browser, fetched.challenge.context.location.flatMap { $0.isEmpty ? nil : $0 }) {
            case (let browser?, let place?): String(localized: "\(browser), near \(place)")
            case (let browser?, nil): browser
            default: String(localized: "Approve the sign-in to Qeet ID.")
            }
        let outcome = await lock.authenticate(reason: reason)
        switch outcome {
        case .success:
            break
        case .cancelled:
            return
        case .failed:
            numberError = String(localized: "\(lock.biometry.name) didn't confirm it's you, so nothing was sent. Try again.")
            return
        case .passcodeNotSet:
            alert = QeetrixAlertDialog(
                "Set a passcode first",
                message: Text("Approving a sign-in needs Face ID or the passcode. Set a passcode in iOS Settings, then try again."))
            return
        }
        do {
            try await link.respond(to: id, approved: true, number: value)
            phase = .outcome(.approved(browser: UserAgentDescription.describe(fetched.challenge.context.userAgent)))
        } catch {
            handle(error)
        }
    }

    func deny() async {
        guard case .review = phase, !isApproving, !isDenying else { return }
        isDenying = true
        defer { isDenying = false }
        do {
            try await link.respond(to: id, approved: false, number: nil)
            phase = .outcome(.denied)
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: APIError) {
        switch error {
        case .numberMismatch: phase = .outcome(.ended(.numberMismatch))
        case .challengeExpired: phase = .outcome(.ended(.expired))
        case .challengeAnswered: phase = .outcome(.ended(.answered))
        case .notFound: phase = .outcome(.ended(.notFound))
        case .unauthorized: phase = .outcome(.ended(.notLinked))
        case .cancelled: break
        default:
            alert = QeetrixAlertDialog("Couldn't send your answer", message: Text(error.connectionMessage))
        }
    }
}

extension SignInChallenge.Context {
    /// "Chrome on macOS", or nothing when the browser isn't recognised.
    var browser: String? { UserAgentDescription.describe(userAgent) }
}
