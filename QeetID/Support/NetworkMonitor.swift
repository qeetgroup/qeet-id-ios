import Network
import Observation

/// Whether the iPhone is online, for "You're offline" on the Accounts screen.
@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isOffline = false
    @ObservationIgnored private let monitor = NWPathMonitor()

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isOffline = path.status != .satisfied
            Task { @MainActor in self?.isOffline = isOffline }
        }
        monitor.start(queue: DispatchQueue(label: "com.qeetgroup.qeetid.network"))
    }
}
