import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI non inoltra `applicationShouldHandleReopen` a questo delegate:
        // si intercetta direttamente l'evento Apple inviato quando si riapre l'app.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleReopen(_:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEReopenApplication)
        )

        OnboardingWindow.shared.showIfNeeded(controller: .shared, loginItem: .shared, updater: .shared)
        Updater.shared.start()
    }

    /// Riaprire l'app già in esecuzione (Spotlight, Finder, `open`) fa ricomparire l'icona.
    @objc private func handleReopen(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        UserDefaults.standard.set(true, forKey: MenuBarIcon.visibleKey)
    }
}
