import Foundation

/// Who the app is: the identifiers the app and its extensions share, read from each target's
/// Info.plist, where the build settings put them.
enum AppIdentity {
    /// The App Group the app and its extensions share.
    static var appGroup: String {
        Bundle.main.object(forInfoDictionaryKey: "QeetIDAppGroup") as? String ?? "group.com.qeetgroup.qeetid"
    }
}
