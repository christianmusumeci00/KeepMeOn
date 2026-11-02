import AppKit
import KeepMeOnCore
import SwiftUI

/// Contenuto del menu nella barra dei menu (stile `.menu`: un normale NSMenu).
struct MenuContent: View {
    @ObservedObject var controller: KeeperController
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var updater: Updater
    @ObservedObject var localization = Localization.shared

    var body: some View {
        Text(statusText)
        if controller.state == .active, let last = controller.lastDeclaration {
            Text(tr("Last action at \(last.formatted(date: .omitted, time: .shortened))",
                     "Ultimo intervento alle \(last.formatted(date: .omitted, time: .shortened))"))
        }
        if !controller.hasEventAccess {
            Button(tr("Grant Accessibility Permission…", "Concedi il permesso di Accessibilità…")) {
                controller.requestEventAccess()
            }
        }

        Divider()

        Toggle(tr("Enabled", "Attivo"), isOn: $controller.isEnabled)
        Picker(tr("Check Interval", "Intervallo di controllo"), selection: $controller.interval) {
            ForEach(KeeperController.intervalOptions, id: \.self) { seconds in
                Text(tr("\(seconds) seconds", "\(seconds) secondi")).tag(seconds)
            }
        }

        Divider()

        Toggle(tr("Work Hours Only", "Solo in orario di lavoro"), isOn: $controller.workHoursOnly)
        if controller.workHoursOnly {
            Text(tr("Hours: ", "Orario: ") + controller.workHours.summary(in: localization.language))
        }
        Toggle(tr("Lunch Break", "Pausa pranzo"), isOn: $controller.lunchBreakEnabled)
        if controller.lunchBreakEnabled {
            Text(tr("Break: ", "Pausa: ") + controller.lunchBreak.summary)
        }
        Button(tr("Settings…", "Impostazioni…")) {
            SettingsWindow.shared.show(controller: controller)
        }

        Divider()

        Toggle(tr("Launch at Login", "Avvia al login"), isOn: Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.setEnabled($0) }
        ))

        Button(tr("Hide Icon…", "Nascondi icona…")) {
            MenuBarIcon.confirmHide()
        }
        Button(tr("Guided Setup…", "Configurazione guidata…")) {
            OnboardingWindow.shared.show(controller: controller, loginItem: loginItem, updater: updater, fromStart: true)
        }

        Divider()

        Button(updater.isBusy
               ? tr("Checking for Updates…", "Controllo aggiornamenti in corso…")
               : tr("Check for Updates…", "Controlla aggiornamenti…")) {
            updater.checkNow()
        }
        .disabled(updater.isBusy)
        Toggle(tr("Automatic Updates", "Aggiornamenti automatici"), isOn: $updater.automaticChecks)
        Text("KeepMeOn \(updater.currentVersion.description)")

        Divider()

        Button(tr("Quit", "Esci")) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var statusText: String {
        switch controller.state {
        case .off: tr("Off", "Disattivato")
        case .active where !controller.hasEventAccess:
            tr("Active – permission missing, Teams may go Away", "Attivo – manca il permesso, Teams può andare in Assente")
        case .active: tr("Active – checking every \(controller.interval) s", "Attivo – controllo ogni \(controller.interval) s")
        case .pausedOutsideHours: tr("Paused – outside work hours", "In pausa – fuori orario")
        case .pausedLunch: tr("Paused – lunch break", "In pausa – pausa pranzo")
        case .pausedScreenLocked: tr("Paused – screen locked", "In pausa – schermo bloccato")
        case .pausedAsleep: tr("Paused – Mac or display asleep", "In pausa – Mac o schermo in stop")
        }
    }
}
