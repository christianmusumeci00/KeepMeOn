import AppKit
import KeepMeOnCore
import SwiftUI

/// Contenuto del menu nella barra dei menu (stile `.menu`: un normale NSMenu).
struct MenuContent: View {
    @ObservedObject var controller: KeeperController
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var updater: Updater

    var body: some View {
        Text(statusText)
        if controller.state == .active, let last = controller.lastDeclaration {
            Text("Ultimo intervento alle \(last.formatted(date: .omitted, time: .shortened))")
        }
        if !controller.hasEventAccess {
            Button("Concedi il permesso di Accessibilità…") {
                controller.requestEventAccess()
            }
        }

        Divider()

        Toggle("Attivo", isOn: $controller.isEnabled)
        Picker("Intervallo di controllo", selection: $controller.interval) {
            ForEach(KeeperController.intervalOptions, id: \.self) { seconds in
                Text("\(seconds) secondi").tag(seconds)
            }
        }

        Divider()

        Toggle("Solo in orario di lavoro", isOn: $controller.workHoursOnly)
        if controller.workHoursOnly {
            Text("Orario: \(controller.workHours.summary)")
        }
        Toggle("Pausa pranzo", isOn: $controller.lunchBreakEnabled)
        if controller.lunchBreakEnabled {
            Text("Pausa: \(controller.lunchBreak.summary)")
        }
        Button("Imposta orari…") {
            SettingsWindow.shared.show(controller: controller)
        }

        Divider()

        Toggle("Avvia al login", isOn: Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.setEnabled($0) }
        ))

        Button("Nascondi icona…") {
            MenuBarIcon.confirmHide()
        }
        Button("Configurazione guidata…") {
            OnboardingWindow.shared.show(controller: controller, loginItem: loginItem, updater: updater, fromStart: true)
        }

        Divider()

        Button(updater.isBusy ? "Controllo aggiornamenti in corso…" : "Controlla aggiornamenti…") {
            updater.checkNow()
        }
        .disabled(updater.isBusy)
        Toggle("Aggiornamenti automatici", isOn: $updater.automaticChecks)
        Text("KeepMeOn \(updater.currentVersion.description)")

        Divider()

        Button("Esci") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var statusText: String {
        switch controller.state {
        case .off: "Disattivato"
        case .active where !controller.hasEventAccess: "Attivo – manca il permesso, Teams può andare in Assente"
        case .active: "Attivo – controllo ogni \(controller.interval) s"
        case .pausedOutsideHours: "In pausa – fuori orario"
        case .pausedLunch: "In pausa – pausa pranzo"
        case .pausedScreenLocked: "In pausa – schermo bloccato"
        case .pausedAsleep: "In pausa – Mac o schermo in stop"
        }
    }
}
