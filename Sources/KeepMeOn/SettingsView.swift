import AppKit
import Combine
import KeepMeOnCore
import SwiftUI

/// Finestra delle impostazioni: lingua, fascia di lavoro (inizio, fine, giorni) e pausa pranzo.
struct SettingsView: View {
    @ObservedObject var controller: KeeperController
    @ObservedObject var localization = Localization.shared

    var body: some View {
        Form {
            LanguagePicker(localization: localization)

            Divider()
                .padding(.vertical, 6)

            Toggle(tr("Work hours only", "Solo in orario di lavoro"), isOn: $controller.workHoursOnly)
            WorkHoursFields(controller: controller)
                .disabled(!controller.workHoursOnly)
            Note(text: controller.workHoursNote)

            Divider()
                .padding(.vertical, 6)

            Toggle(tr("Lunch break", "Pausa pranzo"), isOn: $controller.lunchBreakEnabled)
            LunchBreakFields(controller: controller)
                .disabled(!controller.lunchBreakEnabled)
            Note(text: tr("During the lunch break KeepMeOn doesn't step in, every day.",
                          "Durante la pausa pranzo KeepMeOn non interviene, tutti i giorni."))
        }
        .formStyle(.columns)
        // Ricostruisce tutti i controlli quando cambia la lingua, anche le etichette dei campi.
        .id(localization.language)
        .padding(20)
        .frame(width: 500)
    }
}

/// Scelta della lingua: nelle impostazioni e nella configurazione guidata.
struct LanguagePicker: View {
    @ObservedObject var localization: Localization

    var body: some View {
        Picker(tr("Language:", "Lingua:"), selection: $localization.language) {
            ForEach(Language.allCases, id: \.self) { language in
                Text(language.displayName).tag(language)
            }
        }
        .fixedSize()
    }
}

/// Ora di inizio, ora di fine e giorni: nella finestra degli orari e nella configurazione guidata.
struct WorkHoursFields: View {
    @ObservedObject var controller: KeeperController

    var body: some View {
        DatePicker(tr("Start:", "Inizio:"), selection: controller.timeBinding(\.workHours.startMinute), displayedComponents: .hourAndMinute)
        DatePicker(tr("End:", "Fine:"), selection: controller.timeBinding(\.workHours.endMinute), displayedComponents: .hourAndMinute)
        LabeledContent(tr("Days:", "Giorni:")) {
            HStack(spacing: 10) {
                ForEach(WorkHours.mondayFirst, id: \.self) { day in
                    Toggle(WorkHours.shortName(of: day, in: .current).capitalized, isOn: controller.weekdayBinding(day))
                        .toggleStyle(.checkbox)
                }
            }
            .fixedSize()
        }
    }
}

/// Inizio e fine della pausa pranzo.
struct LunchBreakFields: View {
    @ObservedObject var controller: KeeperController

    var body: some View {
        DatePicker(tr("From:", "Dalle:"), selection: controller.timeBinding(\.lunchBreak.startMinute), displayedComponents: .hourAndMinute)
        DatePicker(tr("To:", "Alle:"), selection: controller.timeBinding(\.lunchBreak.endMinute), displayedComponents: .hourAndMinute)
    }
}

/// Testo secondario sotto un gruppo di controlli.
struct Note: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension KeeperController {
    var workHoursNote: String {
        var lines = [tr("Outside these hours KeepMeOn stays on but doesn't step in.",
                        "Fuori fascia KeepMeOn resta acceso ma non interviene.")]
        if workHours.startMinute == workHours.endMinute {
            lines.append(tr("Start and end are the same: the range covers the whole day.",
                            "Inizio e fine coincidono: la fascia copre l'intera giornata."))
        } else if workHours.startMinute > workHours.endMinute {
            lines.append(tr("The range ends the next day, like a night shift.",
                            "La fascia termina il giorno dopo, come un turno di notte."))
        }
        return lines.joined(separator: " ")
    }

    /// Collega un orario in minuti dalla mezzanotte a un `DatePicker`.
    func timeBinding(_ keyPath: ReferenceWritableKeyPath<KeeperController, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute = self[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                self[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { self.workHours.weekdays.contains(weekday) },
            set: { selected in
                if selected {
                    self.workHours.weekdays.insert(weekday)
                } else {
                    self.workHours.weekdays.remove(weekday)
                }
            }
        )
    }
}

/// Mostra `SettingsView` in un `NSWindow`.
///
/// Non si usa la scena `Settings` di SwiftUI: in un'app senza Dock aprirla dal menu
/// richiede `SettingsLink` (solo macOS 14+) o selettori privati, e spesso la finestra
/// resta dietro alle altre.
@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var window: NSWindow?
    private var titleBinding: AnyCancellable?

    func show(controller: KeeperController) {
        let window = self.window ?? makeWindow(controller: controller)
        self.window = window
        NSApp.activateIgnoringOtherAppsIfNeeded()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(controller: KeeperController) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(controller: controller)))
        titleBinding = Localization.shared.bindTitle(of: window, "KeepMeOn – Settings", "KeepMeOn – Impostazioni")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
