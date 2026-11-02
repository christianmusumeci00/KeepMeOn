import SwiftUI

/// App da sola barra dei menu: niente Dock (LSUIElement nell'Info.plist) e nessuna finestra principale.
@main
struct KeepMeOnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = KeeperController.shared
    @StateObject private var loginItem = LoginItem.shared
    @StateObject private var updater = Updater.shared
    @AppStorage(MenuBarIcon.visibleKey) private var showsIcon = true

    init() {
        // Prima di qualsiasi finestra: fissa la lingua (e la conserva per chi aggiorna dalla 1.2).
        _ = Localization.shared
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $showsIcon) {
            MenuContent(controller: controller, loginItem: loginItem, updater: updater)
        } label: {
            Image(nsImage: MenuBarIcon.image(
                isEnabled: controller.isEnabled,
                isCovering: controller.state == .active && controller.hasEventAccess
            ))
            .accessibilityLabel("KeepMeOn")
        }
        .menuBarExtraStyle(.menu)
    }
}
