import AppKit

/// Icona nella barra dei menu, che si può nascondere: l'app continua a funzionare
/// senza nulla di visibile. Riaprendo KeepMeOn (Spotlight, Finder) l'icona ricompare.
enum MenuBarIcon {
    /// Chiave in UserDefaults, letta da `@AppStorage` in `KeepMeOnApp`.
    static let visibleKey = "showMenuBarIcon"

    /// Tazzina vuota se l'app è spenta, piena se è accesa, con la spunta
    /// quando sta davvero tenendo verde lo stato (attiva, con permesso, non in pausa).
    @MainActor
    static func image(isEnabled: Bool, isCovering: Bool) -> NSImage {
        guard isEnabled else { return off }
        return isCovering ? covering : idle
    }

    @MainActor private static let off = compose("cup.and.saucer", checkBadge: false)
    @MainActor private static let idle = compose("cup.and.saucer.fill", checkBadge: false)
    @MainActor private static let covering = compose("cup.and.saucer.fill", checkBadge: true)

    /// Disegna la tazzina, con la spunta facoltativa in basso a destra staccata da un
    /// sottile bordo trasparente. Tutte le varianti hanno la stessa tela, così l'icona
    /// non si sposta nella barra quando cambia stato. Resta un'immagine template:
    /// macOS la colora come le icone di sistema, in tema chiaro e scuro.
    private static func compose(_ symbolName: String, checkBadge: Bool) -> NSImage {
        let cupConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let badgeConfig = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        guard let cup = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(cupConfig),
              let check = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(badgeConfig)
        else { return NSImage() }

        let size = NSSize(width: cup.size.width + 3, height: cup.size.height + 2)
        let image = NSImage(size: size, flipped: false) { bounds in
            cup.draw(in: NSRect(x: 0, y: bounds.height - cup.size.height,
                                width: cup.size.width, height: cup.size.height))
            guard checkBadge else { return true }
            let badge = NSRect(x: bounds.width - check.size.width, y: 0,
                               width: check.size.width, height: check.size.height)
            // Ritaglio rotondo sotto la spunta, così si distingue dalla tazzina.
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: badge.insetBy(dx: -1.5, dy: -1.5)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            check.draw(in: badge)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "KeepMeOn"
        return image
    }

    @MainActor
    static func confirmHide() {
        let alert = NSAlert()
        alert.messageText = tr("Hide the icon?", "Nascondere l'icona?")
        alert.informativeText = tr(
            "KeepMeOn will keep working with nothing visible. To bring the icon back, open KeepMeOn again from Spotlight or the Applications folder.",
            "KeepMeOn continuerà a funzionare senza nulla di visibile. Per far ricomparire l'icona riapri KeepMeOn da Spotlight o dalla cartella Applicazioni.")
        alert.addButton(withTitle: tr("Hide", "Nascondi"))
        alert.addButton(withTitle: tr("Cancel", "Annulla"))
        NSApp.activateIgnoringOtherAppsIfNeeded()
        if alert.runModal() == .alertFirstButtonReturn {
            UserDefaults.standard.set(false, forKey: visibleKey)
        }
    }
}
