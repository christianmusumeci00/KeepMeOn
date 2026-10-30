import ApplicationServices
import CoreGraphics
import Foundation
import IOKit.pwr_mgt

/// Unico punto di contatto con il sistema per tenere "presente" l'utente.
///
/// Usa due meccanismi complementari:
/// - `IOPMAssertionDeclareUserActivity` comunica a powerd che l'utente è presente: rimanda
///   stop dello schermo, salvaschermo e stop del Mac. Non azzera però il contatore di
///   inattività che legge Teams.
/// - Un evento "modificatori invariati" azzera quel contatore (`combinedSessionState`).
///   Non muove il cursore, non digita e non clicca: per le app equivale a nessun cambiamento.
///   Richiede il permesso di Accessibilità.
final class ActivityKeeper {
    private static let assertionName = "KeepMeOn: utente presente" as CFString
    private static let nullID = IOPMAssertionID(kIOPMNullAssertionID)

    /// Marca gli eventi inviati da KeepMeOn ("KMON"), così si riconoscono in un event tap.
    private static let eventMarker: Int64 = 0x4B4D_4F4E

    /// Tasti modificatori fisici: se uno risulta premuto l'evento non viene inviato.
    private static let heldModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn]

    /// ID riusato a ogni dichiarazione, come chiede la documentazione di IOKit.
    private var assertionID = ActivityKeeper.nullID

    deinit {
        release()
    }

    /// Secondi trascorsi dall'ultimo input reale (mouse, tastiera, trackpad).
    static func systemIdleSeconds() -> TimeInterval {
        // `~0` equivale a kCGAnyInputEventType, che Swift non importa.
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
    }

    // MARK: Dichiarazione a powerd

    /// Dichiara attività utente locale. Restituisce `false` se powerd rifiuta la richiesta.
    @discardableResult
    func declareActivity() -> Bool {
        IOPMAssertionDeclareUserActivity(Self.assertionName, kIOPMUserActiveLocal, &assertionID) == kIOReturnSuccess
    }

    /// Rilascia l'asserzione, se presente. Si può chiamare più volte.
    func release() {
        guard assertionID != Self.nullID else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = Self.nullID
    }

    // MARK: Evento neutro per il contatore di Teams

    /// Vero se macOS consente a KeepMeOn di inviare eventi (Privacy e sicurezza › Accessibilità).
    /// macOS lo valuta all'avvio dell'app: un permesso concesso dopo vale dal prossimo avvio.
    static var canPostEvents: Bool {
        CGPreflightPostEventAccess()
    }

    /// Stato attuale dell'interruttore in Accessibilità, aggiornato anche ad app avviata.
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Aggiunge KeepMeOn all'elenco Accessibilità; la prima volta macOS mostra il proprio avviso.
    static func requestEventAccess() {
        CGRequestPostEventAccess()
    }

    /// Invia un evento `flagsChanged` con gli stessi modificatori già attivi (di solito nessuno,
    /// al massimo Blocco maiuscole): azzera il contatore di inattività senza cambiare nulla per le app.
    /// Non invia nulla se manca il permesso o se un modificatore risulta premuto.
    @discardableResult
    func postNeutralEvent() -> Bool {
        let current = CGEventSource.flagsState(.combinedSessionState)
        guard Self.canPostEvents,
              current.intersection(Self.heldModifiers).isEmpty,
              let event = CGEvent(source: CGEventSource(stateID: .hidSystemState))
        else { return false }

        event.type = .flagsChanged
        event.flags = current
        event.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        event.post(tap: .cghidEventTap)
        return true
    }
}
