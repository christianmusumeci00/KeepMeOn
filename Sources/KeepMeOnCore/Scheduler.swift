import Foundation

/// Stato operativo di KeepMeOn, mostrato nel menu.
public enum KeeperState: Equatable, Sendable {
    /// Disattivato dall'utente.
    case off
    /// In funzione: dichiara attività quando l'utente è inattivo oltre la soglia.
    case active
    case pausedOutsideHours
    case pausedLunch
    case pausedScreenLocked
    /// Mac in stop o schermi spenti.
    case pausedAsleep
}

/// Regole di KeepMeOn come funzioni pure: nessun effetto collaterale, facili da testare.
public enum Scheduler {
    /// Inattività oltre la quale si dichiara attività utente.
    public static let defaultIdleThreshold: TimeInterval = 120

    /// Teams segna "Assente" dopo circa 5 minuti senza input (documentazione Microsoft).
    public static let teamsAwayAfter: TimeInterval = 5 * 60

    /// Margine di sicurezza rispetto ai 5 minuti di Teams.
    static let safetyMargin: TimeInterval = 15

    /// Decide lo stato a partire da impostazioni, condizioni di sistema e ora corrente.
    /// L'ordine conta: spento, poi stop, poi blocco schermo, poi fascia oraria, poi pausa pranzo.
    /// `lunchBreak` è `nil` quando la pausa pranzo è disattivata.
    public static func state(
        isEnabled: Bool,
        isAsleep: Bool,
        isScreenLocked: Bool,
        workHoursOnly: Bool,
        workHours: WorkHours,
        lunchBreak: LunchBreak? = nil,
        now: Date,
        calendar: Calendar = .current
    ) -> KeeperState {
        guard isEnabled else { return .off }
        if isAsleep { return .pausedAsleep }
        if isScreenLocked { return .pausedScreenLocked }
        if workHoursOnly, !workHours.contains(now, calendar: calendar) { return .pausedOutsideHours }
        if let lunchBreak, lunchBreak.contains(now, calendar: calendar) { return .pausedLunch }
        return .active
    }

    /// Vero se va dichiarata attività: solo quando l'utente è fermo da almeno `threshold` secondi,
    /// così mentre lavora l'app non fa nulla.
    public static func shouldDeclareActivity(idleSeconds: TimeInterval, threshold: TimeInterval) -> Bool {
        idleSeconds >= threshold
    }

    /// Soglia di inattività da usare con un certo intervallo di controllo.
    ///
    /// Nel caso peggiore un controllo cade appena prima della soglia e il successivo arriva
    /// un intervallo (più la tolleranza) dopo: l'inattività sale a soglia + intervallo + tolleranza.
    /// Se così si superano i 5 minuti di Teams la soglia scende; succede solo con 240 s.
    public static func idleThreshold(base: TimeInterval, interval: TimeInterval) -> TimeInterval {
        let latestSafe = teamsAwayAfter - safetyMargin - interval - timerTolerance(forInterval: interval)
        return max(0, min(base, latestSafe))
    }

    /// Tolleranza del timer: il 10% dell'intervallo, come consiglia Apple.
    /// Permette al sistema di accorpare i risvegli della CPU.
    public static func timerTolerance(forInterval interval: TimeInterval) -> TimeInterval {
        interval / 10
    }
}
