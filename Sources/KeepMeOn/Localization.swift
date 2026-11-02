import AppKit
import Combine
import KeepMeOnCore

/// Testo nella lingua scelta dall'utente: `tr("Settings", "Impostazioni")`.
/// Le due versioni stanno una accanto all'altra, così si aggiornano insieme.
func tr(_ english: String, _ italian: String) -> String {
    Language.current.pick(english, italian)
}

extension Language {
    /// Chiave in UserDefaults: `defaults write com.keepmeon.app language it`
    static let defaultsKey = "language"

    /// Lingua salvata; l'inglese se non è mai stata scelta.
    static var current: Language {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(Language.init(rawValue:)) ?? .standard
    }
}

/// Lingua dell'interfaccia, osservabile: menu e finestre si ridisegnano appena cambia.
@MainActor
final class Localization: ObservableObject {
    static let shared = Localization()

    @Published var language: Language {
        didSet { defaults.set(language.rawValue, forKey: Language.defaultsKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        let stored = defaults.string(forKey: Language.defaultsKey).flatMap(Language.init(rawValue:))
        // Fino alla 1.2 l'app era solo in italiano: chi l'aveva già configurata la ritrova com'era.
        let migrated: Language? = defaults.bool(forKey: OnboardingWindow.completedKey) ? .italian : nil
        self.defaults = defaults
        language = stored ?? migrated ?? .standard
        // Salvata subito: la regola sopra vale solo per chi aggiorna, non per chi installa ora.
        defaults.set(language.rawValue, forKey: Language.defaultsKey)
    }

    /// Aggiorna il titolo di una finestra a ogni cambio di lingua (e subito).
    func bindTitle(of window: NSWindow, _ english: String, _ italian: String) -> AnyCancellable {
        $language.sink { [weak window] language in
            window?.title = language.pick(english, italian)
        }
    }
}

