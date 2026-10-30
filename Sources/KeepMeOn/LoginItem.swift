import AppKit
import ServiceManagement

/// Avvio al login tramite `SMAppService.mainApp` (macOS 13+).
@MainActor
final class LoginItem: ObservableObject {
    static let shared = LoginItem()

    @Published private(set) var isEnabled = false

    private let service = SMAppService.mainApp

    init() {
        refresh()
    }

    /// Rilegge lo stato: l'utente può cambiarlo anche da Impostazioni di Sistema.
    func refresh() {
        isEnabled = service.status == .enabled
    }

    func setEnabled(_ enable: Bool) {
        do {
            if enable {
                try service.register()
            } else if service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            Log.loginItem.error("Avvio al login: \(error.localizedDescription, privacy: .public)")
            showError(enable: enable, error: error)
        }
        refresh()

        if enable, service.status == .requiresApproval {
            askForApproval()
        }
    }

    private func showError(enable: Bool, error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = enable
            ? "Impossibile attivare l'avvio al login"
            : "Impossibile disattivare l'avvio al login"
        alert.informativeText = """
            \(error.localizedDescription)

            Assicurati di avviare KeepMeOn.app dalla cartella Applicazioni e non da un'immagine disco o dal Cestino.
            """
        present(alert)
    }

    private func askForApproval() {
        let alert = NSAlert()
        alert.messageText = "Serve la tua approvazione"
        alert.informativeText = "macOS chiede di confermare KeepMeOn tra gli elementi di login, in Impostazioni di Sistema › Generali › Elementi login."
        alert.addButton(withTitle: "Apri Impostazioni di Sistema")
        alert.addButton(withTitle: "Più tardi")
        if present(alert) == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    /// Un'app da barra dei menu non è in primo piano: va attivata perché l'avviso sia visibile.
    @discardableResult
    private func present(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activateIgnoringOtherAppsIfNeeded()
        return alert.runModal()
    }
}

extension NSApplication {
    /// `activate(ignoringOtherApps:)` è deprecata da macOS 14, che introduce `activate()`.
    func activateIgnoringOtherAppsIfNeeded() {
        if #available(macOS 14, *) {
            activate()
        } else {
            activate(ignoringOtherApps: true)
        }
    }
}
