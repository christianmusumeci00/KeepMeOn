import AppKit
import KeepMeOnCore
import SwiftUI

/// Finestra degli orari: fascia di lavoro (inizio, fine, giorni) e pausa pranzo.
struct SettingsView: View {
    @ObservedObject var controller: KeeperController

    var body: some View {
        Form {
            Toggle("Solo in orario di lavoro", isOn: $controller.workHoursOnly)

            Group {
                DatePicker("Inizio:", selection: time(\.workHours.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("Fine:", selection: time(\.workHours.endMinute), displayedComponents: .hourAndMinute)
                LabeledContent("Giorni:") {
                    HStack(spacing: 10) {
                        ForEach(WorkHours.mondayFirst, id: \.self) { day in
                            Toggle(WorkHours.shortName(of: day).capitalized, isOn: isSelected(day))
                                .toggleStyle(.checkbox)
                        }
                    }
                    .fixedSize()
                }
            }
            .disabled(!controller.workHoursOnly)

            note(workHoursNote)

            Divider()
                .padding(.vertical, 6)

            Toggle("Pausa pranzo", isOn: $controller.lunchBreakEnabled)

            Group {
                DatePicker("Dalle:", selection: time(\.lunchBreak.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("Alle:", selection: time(\.lunchBreak.endMinute), displayedComponents: .hourAndMinute)
            }
            .disabled(!controller.lunchBreakEnabled)

            note("Durante la pausa pranzo KeepMeOn non interviene, tutti i giorni.")
        }
        .formStyle(.columns)
        .padding(20)
        .frame(width: 500)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var workHoursNote: String {
        var lines = ["Fuori fascia KeepMeOn resta acceso ma non interviene."]
        let hours = controller.workHours
        if hours.startMinute == hours.endMinute {
            lines.append("Inizio e fine coincidono: la fascia copre l'intera giornata.")
        } else if hours.startMinute > hours.endMinute {
            lines.append("La fascia termina il giorno dopo, come un turno di notte.")
        }
        return lines.joined(separator: " ")
    }

    /// Collega un orario in minuti dalla mezzanotte a un `DatePicker`.
    private func time(_ keyPath: ReferenceWritableKeyPath<KeeperController, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute = controller[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                controller[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func isSelected(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { controller.workHours.weekdays.contains(weekday) },
            set: { selected in
                if selected {
                    controller.workHours.weekdays.insert(weekday)
                } else {
                    controller.workHours.weekdays.remove(weekday)
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

    func show(controller: KeeperController) {
        let window = self.window ?? makeWindow(controller: controller)
        self.window = window
        NSApp.activateIgnoringOtherAppsIfNeeded()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(controller: KeeperController) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(controller: controller)))
        window.title = "KeepMeOn – Orari"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
