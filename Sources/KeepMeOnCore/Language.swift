import Foundation

/// Lingua dell'interfaccia. Si sceglie nella configurazione guidata e nelle impostazioni.
public enum Language: String, CaseIterable, Sendable {
    case english = "en"
    case italian = "it"

    /// Predefinita per le nuove installazioni.
    public static let standard = Language.english

    /// Nome della lingua scritto nella lingua stessa, come si usa nei selettori.
    public var displayName: String {
        switch self {
        case .english: "English"
        case .italian: "Italiano"
        }
    }

    /// Il testo nella lingua giusta: `language.pick("Settings", "Impostazioni")`.
    public func pick(_ english: String, _ italian: String) -> String {
        switch self {
        case .english: english
        case .italian: italian
        }
    }
}
