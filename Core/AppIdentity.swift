import Foundation

/// Who the app is: the identifiers the app and its extensions share, read from each target's Info.plist, where the
/// build settings put them (`Configs/Project.xcconfig`).
enum AppIdentity {
    /// The App Group the app and its extensions share.
    static var appGroup: String {
        Bundle.main.object(forInfoDictionaryKey: "QeetIDAppGroup") as? String ?? "group.com.qeetgroup.qeetid"
    }

    /// The Keychain access group the app and its AutoFill extension share: the team prefix and
    /// `com.qeetgroup.qeetid.shared`. `nil` falls back to the target's own default group.
    static var keychainGroup: String? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "QeetIDKeychainGroup") as? String,
            !group.isEmpty, !group.contains("$(")
        else { return nil }
        return group
    }

    /// Defaults in the App Group: only what an extension must read (the Debug API address).
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    /// The version people see: "1.0.0".
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    /// The build number.
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
