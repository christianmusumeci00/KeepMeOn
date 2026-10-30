using System.Windows.Forms;
using Microsoft.Win32;

namespace KeepMeOn
{
    /// <summary>
    /// Avvio all'accesso a Windows con la chiave Run dell'utente (nessun permesso di amministratore).
    /// Tiene conto anche dell'interruttore "App di avvio" di Gestione attività e Impostazioni.
    /// </summary>
    internal static class StartupItem
    {
        private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string ApprovedKey = @"Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run";
        private const string ValueName = "KeepMeOn";

        private static string Command => "\"" + Application.ExecutablePath + "\"";

        public static bool IsEnabled
        {
            get
            {
                using (var run = Registry.CurrentUser.OpenSubKey(RunKey))
                {
                    if (run?.GetValue(ValueName) == null)
                    {
                        return false;
                    }
                }
                return !IsDisabledInTaskManager;
            }
        }

        public static void SetEnabled(bool enabled)
        {
            using (var run = Registry.CurrentUser.CreateSubKey(RunKey))
            {
                if (enabled)
                {
                    run.SetValue(ValueName, Command, RegistryValueKind.String);
                }
                else
                {
                    run.DeleteValue(ValueName, false);
                }
            }
            // Una disattivazione fatta da Gestione attività prevale sulla chiave Run: la si azzera.
            using (var approved = Registry.CurrentUser.OpenSubKey(ApprovedKey, writable: true))
            {
                approved?.DeleteValue(ValueName, false);
            }
            Log.Write(enabled ? "Avvio all'accesso attivato" : "Avvio all'accesso disattivato");
        }

        /// <summary>Gestione attività scrive 02 (attiva) o 03 (disattivata) nel primo byte.</summary>
        private static bool IsDisabledInTaskManager
        {
            get
            {
                using (var approved = Registry.CurrentUser.OpenSubKey(ApprovedKey))
                {
                    return approved?.GetValue(ValueName) is byte[] data && data.Length > 0 && (data[0] & 1) == 1;
                }
            }
        }
    }
}
