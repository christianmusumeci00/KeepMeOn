import AppKit
import SwiftUI

/// Schermata di benvenuto: a cosa serve KeepMeOn, come funziona e permesso di Accessibilità.
struct WelcomeView: View {
    @ObservedObject var controller: KeeperController
    @ObservedObject var loginItem: LoginItem
    var onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Text("Ti alzi per un caffè, rispondi al citofono o vai a ritirare una stampa: dopo pochi minuti senza mouse e tastiera Teams ti segna «Assente», anche se stai per tornare. KeepMeOn tiene il Mac sveglio durante queste brevi pause, così resti verde e i colleghi sanno che sei raggiungibile.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 14) {
                feature("cup.and.saucer", "Pause brevi, stato verde",
                        "Interviene solo dopo 2 minuti in cui non usi il Mac: mentre lavori non fa nulla.")
                feature("hand.raised", "Non tocca niente",
                        "Non muove il mouse, non preme tasti e non clicca: invia soltanto un segnale neutro al sistema.")
                feature("pause.circle", "Si ferma da sola",
                        "Con lo schermo bloccato, a Mac in stop, fuori dall'orario di lavoro e durante la pausa pranzo.")
                feature("lock", "Via per più tempo?",
                        "Blocca il Mac con ⌃⌘Q: KeepMeOn si mette in pausa e Teams mostra correttamente che sei assente.")
            }

            permissionCard

            Toggle("Avvia KeepMeOn al login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            ))

            HStack {
                Button("Imposta orari…") {
                    SettingsWindow.shared.show(controller: controller)
                }
                Spacer()
                Button("Inizia", action: onStart)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(width: 520)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("Benvenuto in KeepMeOn")
                    .font(.title.weight(.semibold))
                Text("Resta disponibile su Teams anche quando ti allontani per un attimo.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func feature(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var permissionCard: some View {
        let granted = controller.hasEventAccess
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(granted ? Color.green : Color.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(granted ? "Permesso attivo" : "Serve il permesso di Accessibilità")
                    .fontWeight(.semibold)
                Text(granted
                     ? "KeepMeOn è pronta. Puoi revocare il permesso quando vuoi da Impostazioni di Sistema › Privacy e sicurezza › Accessibilità."
                     : "Serve per inviare il segnale neutro. Apri le impostazioni e attiva KeepMeOn nell'elenco: l'app si riavvierà da sola e ritroverai qui il permesso attivo.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !granted {
                    Button("Apri Impostazioni Accessibilità") {
                        controller.requestEventAccess()
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Mostra `WelcomeView` in un `NSWindow`: al primo avvio e dal menu ("Come funziona…").
/// Si considera vista quando l'utente la chiude o preme "Inizia".
@MainActor
final class WelcomeWindow: NSObject, NSWindowDelegate {
    static let shared = WelcomeWindow()

    private static let completedKey = "welcomeCompleted"

    private var window: NSWindow?

    func showIfNeeded(controller: KeeperController, loginItem: LoginItem) {
        guard !UserDefaults.standard.bool(forKey: Self.completedKey) else { return }
        show(controller: controller, loginItem: loginItem)
    }

    func show(controller: KeeperController, loginItem: LoginItem) {
        let window = self.window ?? makeWindow(controller: controller, loginItem: loginItem)
        self.window = window
        NSApp.activateIgnoringOtherAppsIfNeeded()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(controller: KeeperController, loginItem: LoginItem) -> NSWindow {
        let view = WelcomeView(controller: controller, loginItem: loginItem) { [weak self] in
            self?.window?.close()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Benvenuto in KeepMeOn"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
    }
}
