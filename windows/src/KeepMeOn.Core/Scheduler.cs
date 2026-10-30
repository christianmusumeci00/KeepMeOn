using System;

namespace KeepMeOn.Core
{
    /// <summary>Stato operativo di KeepMeOn, mostrato nel menu.</summary>
    public enum KeeperState
    {
        /// <summary>Disattivato dall'utente.</summary>
        Off,
        /// <summary>In funzione: interviene quando l'utente è inattivo oltre la soglia.</summary>
        Active,
        PausedOutsideHours,
        PausedLunch,
        PausedScreenLocked,
        /// <summary>PC in sospensione o schermo spento.</summary>
        PausedAsleep,
    }

    /// <summary>Regole di KeepMeOn come funzioni pure: nessun effetto collaterale, facili da testare.</summary>
    public static class Scheduler
    {
        /// <summary>Inattività oltre la quale si interviene.</summary>
        public const double DefaultIdleThresholdSeconds = 120;

        /// <summary>Teams segna "Assente" dopo circa 5 minuti senza input (documentazione Microsoft).</summary>
        public const double TeamsAwayAfterSeconds = 5 * 60;

        /// <summary>Margine di sicurezza rispetto ai 5 minuti di Teams.</summary>
        internal const double SafetyMarginSeconds = 15;

        /// <summary>
        /// Decide lo stato a partire da impostazioni, condizioni di sistema e ora corrente.
        /// L'ordine conta: spento, poi sospensione, poi blocco schermo, poi fascia oraria, poi pausa pranzo.
        /// <paramref name="lunchBreak"/> è <c>null</c> quando la pausa pranzo è disattivata.
        /// </summary>
        public static KeeperState State(
            bool isEnabled,
            bool isAsleep,
            bool isScreenLocked,
            bool workHoursOnly,
            WorkHours workHours,
            LunchBreak lunchBreak,
            DateTime now)
        {
            if (!isEnabled) return KeeperState.Off;
            if (isAsleep) return KeeperState.PausedAsleep;
            if (isScreenLocked) return KeeperState.PausedScreenLocked;
            if (workHoursOnly && !workHours.Contains(now)) return KeeperState.PausedOutsideHours;
            if (lunchBreak != null && lunchBreak.Contains(now)) return KeeperState.PausedLunch;
            return KeeperState.Active;
        }

        /// <summary>
        /// Vero se va dichiarata attività: solo quando l'utente è fermo da almeno <paramref name="threshold"/> secondi,
        /// così mentre lavora l'app non fa nulla.
        /// </summary>
        public static bool ShouldDeclareActivity(double idleSeconds, double threshold) => idleSeconds >= threshold;

        /// <summary>Ritardo massimo previsto di un controllo del timer: il 10% dell'intervallo.</summary>
        public static double TimerToleranceSeconds(double intervalSeconds) => intervalSeconds / 10;

        /// <summary>
        /// Soglia di inattività da usare con un certo intervallo di controllo.
        /// Nel caso peggiore un controllo cade appena prima della soglia e il successivo arriva
        /// un intervallo (più la tolleranza) dopo: l'inattività sale a soglia + intervallo + tolleranza.
        /// Se così si superano i 5 minuti di Teams la soglia scende; succede solo con 240 s.
        /// </summary>
        public static double IdleThreshold(double baseSeconds, double intervalSeconds)
        {
            double latestSafe = TeamsAwayAfterSeconds - SafetyMarginSeconds - intervalSeconds - TimerToleranceSeconds(intervalSeconds);
            return Math.Max(0, Math.Min(baseSeconds, latestSafe));
        }
    }
}
