using System;
using System.Windows.Forms;
using KeepMeOn.Core;

namespace KeepMeOn
{
    /// <summary>Menu dell'icona nell'area di notifica, con le stesse voci della versione per Mac.</summary>
    internal sealed class TrayMenu : IDisposable
    {
        private readonly KeeperController controller;
        private readonly Updater updater;
        private readonly ToolStripMenuItem status = Info();
        private readonly ToolStripMenuItem lastIntervention = Info();
        private readonly ToolStripMenuItem enabled = new ToolStripMenuItem();
        private readonly ToolStripMenuItem interval = new ToolStripMenuItem();
        private readonly ToolStripMenuItem workHoursOnly = new ToolStripMenuItem();
        private readonly ToolStripMenuItem workHoursSummary = Info();
        private readonly ToolStripMenuItem lunchBreak = new ToolStripMenuItem();
        private readonly ToolStripMenuItem lunchSummary = Info();
        private readonly ToolStripMenuItem settingsItem = new ToolStripMenuItem();
        private readonly ToolStripMenuItem startup = new ToolStripMenuItem();
        private readonly ToolStripMenuItem hideIcon = new ToolStripMenuItem();
        private readonly ToolStripMenuItem onboarding = new ToolStripMenuItem();
        private readonly ToolStripMenuItem checkUpdates = new ToolStripMenuItem();
        private readonly ToolStripMenuItem automaticUpdates = new ToolStripMenuItem();
        private readonly ToolStripMenuItem version = Info();
        private readonly ToolStripMenuItem exit = new ToolStripMenuItem();

        public TrayMenu(KeeperController controller, Updater updater)
        {
            this.controller = controller;
            this.updater = updater;

            enabled.Click += (sender, e) => controller.IsEnabled = !controller.IsEnabled;
            foreach (int seconds in KeeperController.IntervalOptions)
            {
                var option = new ToolStripMenuItem { Tag = seconds };
                option.Click += (sender, e) => controller.Interval = seconds;
                interval.DropDownItems.Add(option);
            }
            workHoursOnly.Click += (sender, e) => controller.WorkHoursOnly = !controller.WorkHoursOnly;
            lunchBreak.Click += (sender, e) => controller.LunchBreakEnabled = !controller.LunchBreakEnabled;
            settingsItem.Click += (sender, e) => SettingsRequested?.Invoke(this, EventArgs.Empty);
            startup.Click += (sender, e) =>
            {
                StartupItem.SetEnabled(!StartupItem.IsEnabled);
                Refresh();
            };
            checkUpdates.Click += async (sender, e) => await updater.CheckAsync(userInitiated: true);
            automaticUpdates.Click += (sender, e) => updater.AutomaticChecks = !updater.AutomaticChecks;
            hideIcon.Click += (sender, e) => HideIconRequested?.Invoke(this, EventArgs.Empty);
            onboarding.Click += (sender, e) => OnboardingRequested?.Invoke(this, EventArgs.Empty);
            exit.Click += (sender, e) => ExitRequested?.Invoke(this, EventArgs.Empty);
            version.Text = $"KeepMeOn {updater.CurrentVersion}";

            Menu = new ContextMenuStrip();
            Menu.Items.AddRange(new ToolStripItem[]
            {
                status,
                lastIntervention,
                new ToolStripSeparator(),
                enabled,
                interval,
                new ToolStripSeparator(),
                workHoursOnly,
                workHoursSummary,
                lunchBreak,
                lunchSummary,
                settingsItem,
                new ToolStripSeparator(),
                startup,
                hideIcon,
                onboarding,
                new ToolStripSeparator(),
                checkUpdates,
                automaticUpdates,
                version,
                new ToolStripSeparator(),
                exit,
            });
            Menu.Opening += (sender, e) => Refresh();
            controller.Changed += OnControllerChanged;
            updater.Changed += OnControllerChanged;
            L10n.Changed += OnControllerChanged;
            Refresh();
        }

        public ContextMenuStrip Menu { get; }

        public event EventHandler SettingsRequested;
        public event EventHandler HideIconRequested;
        public event EventHandler OnboardingRequested;
        public event EventHandler ExitRequested;

        public static string StatusText(KeeperState state, int interval)
        {
            switch (state)
            {
                case KeeperState.Off: return L10n.T("Off", "Disattivato");
                case KeeperState.Active: return L10n.T($"Active – checking every {interval} s", $"Attivo – controllo ogni {interval} s");
                case KeeperState.PausedOutsideHours: return L10n.T("Paused – outside work hours", "In pausa – fuori orario");
                case KeeperState.PausedLunch: return L10n.T("Paused – lunch break", "In pausa – pausa pranzo");
                case KeeperState.PausedScreenLocked: return L10n.T("Paused – screen locked", "In pausa – schermo bloccato");
                case KeeperState.PausedAsleep: return L10n.T("Paused – PC or display asleep", "In pausa – PC o schermo in stop");
                default: return "";
            }
        }

        public void Refresh()
        {
            status.Text = StatusText(controller.State, controller.Interval);

            bool showLast = controller.State == KeeperState.Active && controller.LastIntervention.HasValue;
            lastIntervention.Visible = showLast;
            if (showLast)
            {
                lastIntervention.Text = L10n.T($"Last action at {controller.LastIntervention.Value:HH:mm}",
                                               $"Ultimo intervento alle {controller.LastIntervention.Value:HH:mm}");
            }

            enabled.Text = L10n.T("Enabled", "Attivo");
            enabled.Checked = controller.IsEnabled;
            interval.Text = L10n.T("Check Interval", "Intervallo di controllo");
            foreach (ToolStripMenuItem option in interval.DropDownItems)
            {
                int seconds = (int)option.Tag;
                option.Text = L10n.T($"{seconds} seconds", $"{seconds} secondi");
                option.Checked = seconds == controller.Interval;
            }

            workHoursOnly.Text = L10n.T("Work Hours Only", "Solo in orario di lavoro");
            workHoursOnly.Checked = controller.WorkHoursOnly;
            workHoursSummary.Visible = controller.WorkHoursOnly;
            workHoursSummary.Text = L10n.T("Hours: ", "Orario: ") + controller.WorkHours.Summary(L10n.Current);

            lunchBreak.Text = L10n.T("Lunch Break", "Pausa pranzo");
            lunchBreak.Checked = controller.LunchBreakEnabled;
            lunchSummary.Visible = controller.LunchBreakEnabled;
            lunchSummary.Text = L10n.T("Break: ", "Pausa: ") + controller.LunchBreak.Summary;
            settingsItem.Text = L10n.T("Settings…", "Impostazioni…");

            startup.Text = L10n.T("Start with Windows", "Avvia all'accesso a Windows");
            startup.Checked = StartupItem.IsEnabled;
            hideIcon.Text = L10n.T("Hide Icon…", "Nascondi icona…");
            onboarding.Text = L10n.T("Guided Setup…", "Configurazione guidata…");

            checkUpdates.Enabled = !updater.IsBusy;
            checkUpdates.Text = updater.IsBusy
                ? L10n.T("Checking for Updates…", "Controllo aggiornamenti in corso…")
                : L10n.T("Check for Updates…", "Controlla aggiornamenti…");
            automaticUpdates.Text = L10n.T("Automatic Updates", "Aggiornamenti automatici");
            automaticUpdates.Checked = updater.AutomaticChecks;
            exit.Text = L10n.T("Exit", "Esci");
        }

        /// <summary>Riga informativa, in grigio e non cliccabile.</summary>
        private static ToolStripMenuItem Info() => new ToolStripMenuItem { Enabled = false };

        private void OnControllerChanged(object sender, EventArgs e) => Refresh();

        public void Dispose()
        {
            controller.Changed -= OnControllerChanged;
            updater.Changed -= OnControllerChanged;
            L10n.Changed -= OnControllerChanged;
            Menu.Dispose();
        }
    }
}
