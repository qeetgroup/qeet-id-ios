import os

/// The app's loggers. **Never interpolate a secret, a code, a pairing code, a push token or the device credential**;
/// log what happened and its status, nothing a person typed or the server issued.
enum Log {
    static let subsystem = "com.qeetgroup.qeetid"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let api = Logger(subsystem: subsystem, category: "api")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let push = Logger(subsystem: subsystem, category: "push")
    static let autofill = Logger(subsystem: subsystem, category: "autofill")
}
