import AppKit
import KeepMeOnCore
import SwiftUI

/// Passi della configurazione guidata.
enum OnboardingStep: Int, CaseIterable {
    case welcome, permission, schedule, lunchBreak, startup, done

    var title: String {
        switch self {
        case .welcome: "Benvenuto"
        case .permission: "Permesso"
        case .schedule: "Quando"
        case .lunchBreak: "Pausa pranzo"
        case .startup: "Avvio e aggiornamenti"
        case .done: "Tutto pronto"
        }
    }
}

/// Configurazione guidata: al primo avvio e dal menu ("Configurazione guidata…").
/// Il passo corrente è salvato, così dopo il riavvio per il permesso la guida riprende da lì.
struct OnboardingView: View {
    @ObservedObject var controller: KeeperController
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var updater: Updater
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
                if step != .welcome {
                    Button("Indietro") { stepIndex -= 1 }
                }
                Spacer()
                Button(step == .done ? "Inizia" : "Avanti") {
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
                    Text("Benvenuto in KeepMeOn")
                        .font(.title.weight(.semibold))
                    Text("Resta disponibile su Teams anche quando ti allontani per un attimo.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Ti alzi per un caffè, rispondi al citofono o vai a ritirare una stampa: dopo pochi minuti senza mouse e tastiera Teams ti segna «Assente», anche se stai per tornare. KeepMeOn tiene il Mac sveglio durante queste brevi pause, così resti verde e i colleghi sanno che sei raggiungibile.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                feature("cup.and.saucer", "Pause brevi, stato verde",
                        "Interviene solo dopo 2 minuti in cui non usi il Mac: mentre lavori non fa nulla.")
                feature("hand.raised", "Non tocca niente",
                        "Non muove il mouse, non preme tasti e non clicca: invia soltanto un segnale neutro al sistema.")
                feature("pause.circle", "Si ferma da sola",
                        "Con lo schermo bloccato, a Mac in stop e, se vuoi, fuori orario e in pausa pranzo.")
                feature("lock", "Via per più tempo?",
                        "Blocca il Mac con ⌃⌘Q: KeepMeOn si mette in pausa e Teams mostra correttamente che sei assente.")
            }

            Text("In pochi passi scegli quando deve funzionare. Potrai cambiare tutto dal menu della tazzina.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permission: some View {
        let granted = controller.hasEventAccess
        return VStack(alignment: .leading, spacing: 16) {
            StepTitle(text: "Un permesso, una volta sola")
            Text("Per azzerare il contatore di inattività che legge Teams, KeepMeOn invia un segnale neutro al sistema. macOS lo consente solo alle app autorizzate in Accessibilità.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: granted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(granted ? Color.green : Color.orange)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 6) {
                    Text(granted ? "Permesso attivo" : "Serve il permesso di Accessibilità")
                        .fontWeight(.semibold)
                    Text(granted
                         ? "Fatto. Puoi revocarlo quando vuoi da Impostazioni di Sistema › Privacy e sicurezza › Accessibilità."
                         : "Apri le impostazioni e attiva KeepMeOn nell'elenco: l'app si riavvierà da sola e la configurazione riprenderà da qui.")
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

            if !granted {
                Note(text: "Puoi anche andare avanti e concederlo più tardi dal menu della tazzina: finché manca, Teams può andare in «Assente».")
            }
        }
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(text: "Quando deve funzionare?")
            Picker("Quando deve funzionare?", selection: $controller.workHoursOnly) {
                Text("Sempre, quando il Mac è acceso e sbloccato").tag(false)
                Text("Solo in orario di lavoro").tag(true)
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
                Note(text: "KeepMeOn interviene a qualsiasi ora del giorno; si ferma comunque con lo schermo bloccato e a Mac in stop.")
            }
        }
    }

    private var lunchBreak: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(text: "Pausa pranzo")
            Text("A pranzo di solito ci si allontana a lungo: KeepMeOn può fermarsi, così Teams mostra che sei in pausa.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Fermati durante la pausa pranzo", isOn: $controller.lunchBreakEnabled)
            Form {
                LunchBreakFields(controller: controller)
            }
            .formStyle(.columns)
            .disabled(!controller.lunchBreakEnabled)
            Note(text: "La pausa vale tutti i giorni.")
        }
    }

    private var startup: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle(text: "Avvio e aggiornamenti")
            option(
                Toggle("Avvia KeepMeOn al login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                )),
                note: "Parte da sola quando accedi al Mac, senza aprire finestre."
            )
            option(
                Toggle("Controlla aggiornamenti automaticamente", isOn: $updater.automaticChecks),
                note: "Una volta al giorno KeepMeOn guarda su GitHub se c'è una nuova versione e ti chiede se installarla. Puoi farlo anche a mano dal menu, con «Controlla aggiornamenti…»."
            )
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepTitle(text: "Tutto pronto")
            Text("KeepMeOn lavora dalla barra dei menu. Ecco le tue scelte:")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                summary("clock", "Quando",
                        controller.workHoursOnly ? "In orario di lavoro (\(controller.workHours.summary))" : "Sempre")
                summary("fork.knife", "Pausa pranzo",
                        controller.lunchBreakEnabled ? controller.lunchBreak.summary : "No")
                summary("power", "Avvio al login", loginItem.isEnabled ? "Sì" : "No")
                summary("arrow.down.circle", "Aggiornamenti automatici", updater.automaticChecks ? "Sì" : "No")
                summary("lock.shield", "Permesso di Accessibilità",
                        controller.hasEventAccess ? "Attivo" : "Da concedere dal menu")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            Text("L'icona nella barra dei menu")
                .fontWeight(.semibold)
                .padding(.top, 4)
            HStack(spacing: 22) {
                legend(MenuBarIcon.image(isEnabled: false, isCovering: false), "Spenta")
                legend(MenuBarIcon.image(isEnabled: true, isCovering: false), "In pausa")
                legend(MenuBarIcon.image(isEnabled: true, isCovering: true), "Ti tiene verde")
            }

            Note(text: "Puoi cambiare tutto quando vuoi dal menu della tazzina.")
        }
    }

    // MARK: Elementi

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
            Text("Passo \(current.rawValue + 1) di \(OnboardingStep.allCases.count) · \(current.title)")
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
    private static let completedKey = "welcomeCompleted"

    private var window: NSWindow?

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
        window.title = "Configurazione di KeepMeOn"
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
