import os

/// Log di sistema, visibili con:
/// `log stream --predicate 'subsystem == "com.keepmeon.app"' --level debug`
enum Log {
    static let keeper = Logger(subsystem: "com.keepmeon.app", category: "keeper")
    static let loginItem = Logger(subsystem: "com.keepmeon.app", category: "login-item")
    static let updater = Logger(subsystem: "com.keepmeon.app", category: "updater")
}
