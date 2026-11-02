using System;
using System.Globalization;
using KeepMeOn.Core;
using Microsoft.Win32;

namespace KeepMeOn
{
    /// <summary>Impostazioni nel registro dell'utente: HKEY_CURRENT_USER\Software\KeepMeOn.</summary>
    internal sealed class SettingsStore
    {
        public const string DefaultKeyPath = @"Software\KeepMeOn";

        private readonly string keyPath;

        public SettingsStore(string keyPath = DefaultKeyPath)
        {
            this.keyPath = keyPath;
        }

        public bool Enabled
        {
            get => GetInt("Enabled", 1) != 0;
            set => SetInt("Enabled", value ? 1 : 0);
        }

        public int IntervalSeconds
        {
            get => GetInt("IntervalSeconds", 60);
            set => SetInt("IntervalSeconds", value);
        }

        public bool WorkHoursOnly
        {
            get => GetInt("WorkHoursOnly", 0) != 0;
            set => SetInt("WorkHoursOnly", value ? 1 : 0);
        }

        public WorkHours WorkHours
        {
            get => WorkHours.FromMask(
                GetInt("WorkStartMinute", WorkHours.Standard.StartMinute),
                GetInt("WorkEndMinute", WorkHours.Standard.EndMinute),
                GetInt("WorkWeekdayMask", WorkHours.Standard.WeekdayMask));
            set
            {
                SetInt("WorkStartMinute", value.StartMinute);
                SetInt("WorkEndMinute", value.EndMinute);
                SetInt("WorkWeekdayMask", value.WeekdayMask);
            }
        }

        public bool LunchBreakEnabled
        {
            get => GetInt("LunchBreakEnabled", 0) != 0;
            set => SetInt("LunchBreakEnabled", value ? 1 : 0);
        }

        public LunchBreak LunchBreak
        {
            get => new LunchBreak(
                GetInt("LunchStartMinute", LunchBreak.Standard.StartMinute),
                GetInt("LunchEndMinute", LunchBreak.Standard.EndMinute));
            set
            {
                SetInt("LunchStartMinute", value.StartMinute);
                SetInt("LunchEndMinute", value.EndMinute);
            }
        }

        /// <summary>Senza voce nel menu: si cambia con regedit (valore DWORD, in secondi).</summary>
        public int IdleThresholdSeconds => GetInt("IdleThresholdSeconds", (int)Scheduler.DefaultIdleThresholdSeconds);

        public bool ShowTrayIcon
        {
            get => GetInt("ShowTrayIcon", 1) != 0;
            set => SetInt("ShowTrayIcon", value ? 1 : 0);
        }

        /// <summary>Lingua scelta nell'installer o nell'app; null se non è mai stata scelta.</summary>
        public Language? Language
        {
            get => Languages.FromCode(GetString("Language"));
            set => SetString("Language", value?.Code() ?? "");
        }

        public bool WelcomeCompleted
        {
            get => GetInt("WelcomeCompleted", 0) != 0;
            set => SetInt("WelcomeCompleted", value ? 1 : 0);
        }

        public bool AutomaticUpdateChecks
        {
            get => GetInt("AutomaticUpdateChecks", 1) != 0;
            set => SetInt("AutomaticUpdateChecks", value ? 1 : 0);
        }

        public DateTime? LastUpdateCheck
        {
            get => DateTime.TryParse(GetString("LastUpdateCheck"), CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var date)
                ? date
                : (DateTime?)null;
            set => SetString("LastUpdateCheck", value?.ToString("o", CultureInfo.InvariantCulture) ?? "");
        }

        /// <summary>Solo per le prove: indirizzo alternativo della release (anche file:///…).</summary>
        public string UpdateFeedUrl => GetString("UpdateFeedUrl");

        public void DeleteAll() => Registry.CurrentUser.DeleteSubKeyTree(keyPath, false);

        private string GetString(string name)
        {
            using (var key = Registry.CurrentUser.OpenSubKey(keyPath))
            {
                return key?.GetValue(name) as string;
            }
        }

        private void SetString(string name, string value)
        {
            using (var key = Registry.CurrentUser.CreateSubKey(keyPath))
            {
                key.SetValue(name, value, RegistryValueKind.String);
            }
        }

        private int GetInt(string name, int fallback)
        {
            using (var key = Registry.CurrentUser.OpenSubKey(keyPath))
            {
                return key?.GetValue(name) is int value ? value : fallback;
            }
        }

        private void SetInt(string name, int value)
        {
            using (var key = Registry.CurrentUser.CreateSubKey(keyPath))
            {
                key.SetValue(name, value, RegistryValueKind.DWord);
            }
        }
    }
}
