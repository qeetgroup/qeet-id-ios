import UserNotifications

/// Whether sign-in requests can reach this iPhone as notifications.
enum NotificationPermission: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied

    static func current() async -> NotificationPermission {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .allowed
        }
    }

    /// Asks iOS for alerts and sounds. Time-sensitive delivery comes from the app's entitlement, not from this.
    static func request() async -> NotificationPermission {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return granted ? .allowed : await current()
    }
}
