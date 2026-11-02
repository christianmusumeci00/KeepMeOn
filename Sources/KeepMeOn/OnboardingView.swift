import AppKit
import Combine
import KeepMeOnCore
import SwiftUI

/// Passi della configurazione guidata.
enum OnboardingStep: Int, CaseIterable {
    case welcome, permission, schedule, lunchBreak, startup, done

    var title: String {
        switch self {
        case .welcome: tr("Welcome", "Benvenuto")
        case .permission: tr("Permission", "Permesso")
        case .schedule: tr("When", "Quando")
        case .lunchBreak: tr("Lunch Break", "Pausa pranzo")
        case .startup: tr("Startup & Updates", "Avvio e aggiornamenti")
        case .done: tr("All Set", "Tutto pronto")
        }
    }
}

/// Configurazione guidata: al primo avvio e dal menu ("Configurazione guidata…").
/// Il passo corrente è salvato, così dopo il riavvio per il permesso la guida riprende da lì.
struct OnboardingView: View {
    @ObservedObject var controller: KeeperController
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var updater: Updater
    @ObservedObject var localization = Localization.shared
    @AppStorage(OnboardingWindow.stepKey) private var stepIndex = 0
    var onFinish: () -> Void

    private var step: OnboardingStep {
        OnboardingStep(rawValue: stepIndex) ?? .welcome
    }

    var body: some View {
        VStack(spacing: 0) {
            StepIndicator(current: step)
                .padding(.top, 4)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 32)
                .padding(.top, 18)

            Divider()

            HStack {
                if step == .welcome {
                    // La lingua si sceglie subito, prima di leggere il resto.
                    LanguagePicker(localization: localization)
                } else {
                    Button(tr("Back", "Indietro")) { stepIndex -= 1 }
                }
                Spacer()
                Button(step == .done ? tr("Get Started", "Inizia") : tr("Next", "Avanti")) {
                    if step == .done {
                        onFinish()
                    } else {
                        stepIndex += 1
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 560, height: 600)
        // Ricostruisce tutti i controlli quando cambia la lingua, anche quelli dei sotto-elementi.
        .id(localization.language)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .permission: permission
        case .schedule: schedule
        case .lunchBreak: lunchBreak
        case .startup: startup
        case .done: done
        }
    }

    // MARK: Passi

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Welcome to KeepMeOn", "Benvenuto in KeepMeOn"))
                        .font(.title.weight(.semibold))
                    Text(tr("Stay available on Teams even when you step away for a moment.",
                            "Resta disponibile su Teams anche quando ti allontani per un attimo."))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(tr("You get up for a coffee, answer the door or grab a printout: after a few minutes without mouse or keyboard, Teams marks you as “Away”, even though you're about to come back. KeepMeOn keeps your Mac awake during these short breaks, so you stay green and your colleagues know they can reach you.",
                    "Ti alzi per un caffè, rispondi al citofono o vai a ritirare una stampa: dopo pochi minuti senza mouse e tastiera Teams ti segna «Assente», anche se stai per tornare. KeepMeOn tiene il Mac sveglio durante queste brevi pause, così resti verde e i colleghi sanno che sei raggiungibile."))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                feature("cup.and.saucer", tr("Short breaks, green status", "Pause brevi, stato verde"),
                        tr("It only steps in after 2 minutes without using your Mac: while you work, it does nothing.",
                           "Interviene solo dopo 2 minuti in cui non usi il Mac: mentre lavori non fa nulla."))
                feature("hand.raised", tr("Hands off", "Non tocca niente"),
                        tr("It doesn't move the mouse, press keys or click: it only sends a neutral signal to the system.",
                           "Non muove il mouse, non preme tasti e non clicca: invia soltanto un segnale neutro al sistema."))
                feature("pause.circle", tr("Stops on its own", "Si ferma da sola"),
                        tr("When the screen is locked, when your Mac is asleep and, if you like, outside work hours and at lunch.",
                           "Con lo schermo bloccato, a Mac in stop e, se vuoi, fuori orario e in pausa pranzo."))
                feature("lock", tr("Away for longer?", "Via per più tempo?"),
                        tr("Lock your Mac with ⌃⌘Q: KeepMeOn pauses and Teams correctly shows that you're away.",
                           "Blocca il Mac con ⌃⌘Q: KeepMeOn si mette in pausa e Teams mostra correttamente che sei assente."))
            }

            Text(tr("In a few steps, choose when it should run. You can change everything later from the cup menu.",
                    "In pochi passi scegli quando deve funzionare. Potrai cambiare tutto dal menu della tazzina."))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permission: some View {
        let granted = controller.hasEventAccess
        return VStack(alignment: .leading, spacing: 16) {
            StepTitle(text: tr("One permission, just once", "Un permesso, una volta sola"))
            Text(tr("To reset the idle timer that Teams reads, KeepMeOn sends a neutral signal to the system. macOS only allows this for apps authorized under Accessibility.",
                    "Per azzerare il contatore di inattività che legge Teams, KeepMeOn invia un segnale neutro al sistema. macOS lo consente solo alle app autorizzate in Accessibilità."))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: granted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(granted ? Color.green : Color.orange)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 6) {
                    Text(granted
                         ? tr("Permission granted", "Permesso attivo")
                         : tr("Accessibility permission needed", "Serve il permesso di Accessibilità"))
                        .fontWeight(.semibold)
                    Text(granted
                         ? tr("Done. You can revoke it anytime in System Settings › Privacy & Security › Accessibility.",
                              "Fatto. Puoi revocarlo quando vuoi da Impostazioni di Sistema › Privacy e sicurezza › Accessibilità.")
                         : tr("Open the settings and turn on KeepMeOn in the list: the app will relaunch on its own and setup will pick up from here.",
                              "Apri le impostazioni e attiva KeepMeOn nell'elenco: l'app si riavvierà da sola e la configurazione riprenderà da qui."))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !granted {
                        Button(tr("Open Accessibility Settings", "Apri Impostazioni Accessibilità")) {
                            controller.requestEventAccess()
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            if !granted {
                Note(text: tr("You can also continue and grant it later from the cup menu: until then, Teams may show you as “Away”.",
                              "Puoi anche andare avanti e concederlo più tardi dal menu della tazzina: finché manca, Teams può andare in «Assente»."))
            }
        }
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(text: tr("When should it run?", "Quando deve funzionare?"))
            Picker(tr("When should it run?", "Quando deve funzionare?"), selection: $controller.workHoursOnly) {
                Text(tr("Always, when the Mac is on and unlocked", "Sempre, quando il Mac è acceso e sbloccato")).tag(false)
                Text(tr("Only during work hours", "Solo in orario di lavoro")).tag(true)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            if controller.workHoursOnly {
                Form {
                    WorkHoursFields(controller: controller)
                }
                .formStyle(.columns)
                Note(text: controller.workHoursNote)
            } else {
                Note(text: tr("KeepMeOn works at any time of day; it still stops when the screen is locked or the Mac is asleep.",
                              "KeepMeOn interviene a qualsiasi ora del giorno; si ferma comunque con lo schermo bloccato e a Mac in stop."))
            }
        }
    }

    private var lunchBreak: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(text: tr("Lunch Break", "Pausa pranzo"))
            Text(tr("At lunch you're usually away for a while: KeepMeOn can stop, so Teams shows that you're on a break.",
                    "A pranzo di solito ci si allontana a lungo: KeepMeOn può fermarsi, così Teams mostra che sei in pausa."))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(tr("Pause during the lunch break", "Fermati durante la pausa pranzo"), isOn: $controller.lunchBreakEnabled)
            Form {
                LunchBreakFields(controller: controller)
            }
            .formStyle(.columns)
            .disabled(!controller.lunchBreakEnabled)
            Note(text: tr("The break applies every day.", "La pausa vale tutti i giorni."))
        }
    }

    private var startup: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle(text: tr("Startup & Updates", "Avvio e aggiornamenti"))
            option(
                Toggle(tr("Launch KeepMeOn at login", "Avvia KeepMeOn al login"), isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                )),
                note: tr("It starts on its own when you log in to your Mac, without opening any windows.",
                         "Parte da sola quando accedi al Mac, senza aprire finestre.")
            )
            option(
                Toggle(tr("Check for updates automatically", "Controlla aggiornamenti automaticamente"), isOn: $updater.automaticChecks),
                note: tr("Once a day KeepMeOn checks GitHub for a new version and asks whether to install it. You can also do it yourself from the menu, with “Check for Updates…”.",
                         "Una volta al giorno KeepMeOn guarda su GitHub se c'è una nuova versione e ti chiede se installarla. Puoi farlo anche a mano dal menu, con «Controlla aggiornamenti…».")
            )
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepTitle(text: tr("All Set", "Tutto pronto"))
            Text(tr("KeepMeOn works from the menu bar. Here are your choices:",
                    "KeepMeOn lavora dalla barra dei menu. Ecco le tue scelte:"))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                summary("clock", tr("When", "Quando"),
                        controller.workHoursOnly
                            ? tr("During work hours", "In orario di lavoro") + " (\(controller.workHours.summary(in: localization.language)))"
                            : tr("Always", "Sempre"))
                summary("fork.knife", tr("Lunch break", "Pausa pranzo"),
                        controller.lunchBreakEnabled ? controller.lunchBreak.summary : tr("No", "No"))
                summary("power", tr("Launch at login", "Avvio al login"), yesNo(loginItem.isEnabled))
                summary("arrow.down.circle", tr("Automatic updates", "Aggiornamenti automatici"), yesNo(updater.automaticChecks))
                summary("lock.shield", tr("Accessibility permission", "Permesso di Accessibilità"),
                        controller.hasEventAccess
                            ? tr("Granted", "Attivo")
                            : tr("Grant it from the menu", "Da concedere dal menu"))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            Text(tr("The menu bar icon", "L'icona nella barra dei menu"))
                .fontWeight(.semibold)
                .padding(.top, 4)
            HStack(spacing: 22) {
                legend(MenuBarIcon.image(isEnabled: false, isCovering: false), tr("Off", "Spenta"))
                legend(MenuBarIcon.image(isEnabled: true, isCovering: false), tr("Paused", "In pausa"))
                legend(MenuBarIcon.image(isEnabled: true, isCovering: true), tr("Keeping you green", "Ti tiene verde"))
            }

            Note(text: tr("You can change everything anytime from the cup menu.",
                          "Puoi cambiare tutto quando vuoi dal menu della tazzina."))
        }
    }

    // MARK: Elementi

    private func yesNo(_ value: Bool) -> String {
        value ? tr("Yes", "Sì") : tr("No", "No")
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

    private func option(_ toggle: some View, note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            toggle
            Note(text: note)
                .padding(.leading, 20)
        }
    }

    private func summary(_ symbol: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            Text(label)
                .frame(width: 180, alignment: .leading)
            Text(value)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func legend(_ image: NSImage, _ label: String) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: image)
                .renderingMode(.template)
                .foregroundStyle(.primary)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StepTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title2.weight(.semibold))
    }
}

/// Puntini di avanzamento e nome del passo.
private struct StepIndicator: View {
    let current: OnboardingStep

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    Capsule()
                        .fill(step.rawValue <= current.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: step == current ? 22 : 8, height: 8)
                }
            }
            Text(tr("Step \(current.rawValue + 1) of \(OnboardingStep.allCases.count)",
                    "Passo \(current.rawValue + 1) di \(OnboardingStep.allCases.count)") + " · \(current.title)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Mostra `OnboardingView` in un `NSWindow`.
/// La guida si considera completata con «Inizia» oppure chiudendo la finestra.
@MainActor
final class OnboardingWindow: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindow()

    /// Passo corrente, salvato per riprendere dopo il riavvio dovuto al permesso.
    static let stepKey = "onboardingStep"
    /// Stessa chiave del vecchio benvenuto: chi l'aveva già visto non rivede la guida all'aggiornamento.
    static let completedKey = "welcomeCompleted"

    private var window: NSWindow?
    private var titleBinding: AnyCancellable?

    func showIfNeeded(controller: KeeperController, loginItem: LoginItem, updater: Updater) {
        guard !UserDefaults.standard.bool(forKey: Self.completedKey) else { return }
        show(controller: controller, loginItem: loginItem, updater: updater, fromStart: false)
    }

    func show(controller: KeeperController, loginItem: LoginItem, updater: Updater, fromStart: Bool) {
        if fromStart, window?.isVisible != true {
            UserDefaults.standard.set(0, forKey: Self.stepKey)
        }
        let window = self.window ?? makeWindow(controller: controller, loginItem: loginItem, updater: updater)
        self.window = window
        NSApp.activateIgnoringOtherAppsIfNeeded()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(controller: KeeperController, loginItem: LoginItem, updater: Updater) -> NSWindow {
        let view = OnboardingView(controller: controller, loginItem: loginItem, updater: updater) { [weak self] in
            self?.window?.close()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        titleBinding = Localization.shared.bindTitle(of: window, "KeepMeOn Setup", "Configurazione di KeepMeOn")
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
        UserDefaults.standard.set(0, forKey: Self.stepKey)
    }
}
