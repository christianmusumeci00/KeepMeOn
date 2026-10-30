using System;
using System.Windows.Forms;
using KeepMeOn.Core;

namespace KeepMeOn
{
    /// <summary>Menu dell'icona nell'area di notifica, con le stesse voci della versione per Mac.</summary>
    internal sealed class TrayMenu : IDisposable
    {
        private readonly KeeperController controller;
        private readonly ToolStripMenuItem status = Info();
        private readonly ToolStripMenuItem lastIntervention = Info();
        private readonly ToolStripMenuItem enabled = new ToolStripMenuItem("Attivo");
        private readonly ToolStripMenuItem interval = new ToolStripMenuItem("Intervallo di controllo");
        private readonly ToolStripMenuItem workHoursOnly = new ToolStripMenuItem("Solo in orario di lavoro");
        private readonly ToolStripMenuItem workHoursSummary = Info();
        private readonly ToolStripMenuItem lunchBreak = new ToolStripMenuItem("Pausa pranzo");
        private readonly ToolStripMenuItem lunchSummary = Info();
        private readonly ToolStripMenuItem startup = new ToolStripMenuItem("Avvia all'accesso a Windows");

        public TrayMenu(KeeperController controller)
        {
            this.controller = controller;

            enabled.Click += (sender, e) => controller.IsEnabled = !controller.IsEnabled;
            foreach (int seconds in KeeperController.IntervalOptions)
            {
                var option = new ToolStripMenuItem($"{seconds} secondi") { Tag = seconds };
                option.Click += (sender, e) => controller.Interval = seconds;
                interval.DropDownItems.Add(option);
            }
            workHoursOnly.Click += (sender, e) => controller.WorkHoursOnly = !controller.WorkHoursOnly;
            lunchBreak.Click += (sender, e) => controller.LunchBreakEnabled = !controller.LunchBreakEnabled;
            startup.Click += (sender, e) =>
            {
                StartupItem.SetEnabled(!StartupItem.IsEnabled);
                Refresh();
            };

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
                new ToolStripMenuItem("Imposta orari…", null, (sender, e) => SettingsRequested?.Invoke(this, EventArgs.Empty)),
                new ToolStripSeparator(),
                startup,
                new ToolStripMenuItem("Nascondi icona…", null, (sender, e) => HideIconRequested?.Invoke(this, EventArgs.Empty)),
                new ToolStripMenuItem("Come funziona…", null, (sender, e) => WelcomeRequested?.Invoke(this, EventArgs.Empty)),
                new ToolStripSeparator(),
                new ToolStripMenuItem("Esci", null, (sender, e) => ExitRequested?.Invoke(this, EventArgs.Empty)),
            });
            Menu.Opening += (sender, e) => Refresh();
            controller.Changed += OnControllerChanged;
            Refresh();
        }

        public ContextMenuStrip Menu { get; }

        public event EventHandler SettingsRequested;
        public event EventHandler HideIconRequested;
        public event EventHandler WelcomeRequested;
        public event EventHandler ExitRequested;

        public static string StatusText(KeeperState state, int interval)
        {
            switch (state)
            {
                case KeeperState.Off: return "Disattivato";
                case KeeperState.Active: return $"Attivo – controllo ogni {interval} s";
                case KeeperState.PausedOutsideHours: return "In pausa – fuori orario";
                case KeeperState.PausedLunch: return "In pausa – pausa pranzo";
                case KeeperState.PausedScreenLocked: return "In pausa – schermo bloccato";
                case KeeperState.PausedAsleep: return "In pausa – PC o schermo in stop";
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
                lastIntervention.Text = $"Ultimo intervento alle {controller.LastIntervention.Value:HH:mm}";
            }

            enabled.Checked = controller.IsEnabled;
            foreach (ToolStripMenuItem option in interval.DropDownItems)
            {
                option.Checked = (int)option.Tag == controller.Interval;
            }

            workHoursOnly.Checked = controller.WorkHoursOnly;
            workHoursSummary.Visible = controller.WorkHoursOnly;
            workHoursSummary.Text = "Orario: " + controller.WorkHours.Summary;

            lunchBreak.Checked = controller.LunchBreakEnabled;
            lunchSummary.Visible = controller.LunchBreakEnabled;
            lunchSummary.Text = "Pausa: " + controller.LunchBreak.Summary;

            startup.Checked = StartupItem.IsEnabled;
        }

        /// <summary>Riga informativa, in grigio e non cliccabile.</summary>
        private static ToolStripMenuItem Info() => new ToolStripMenuItem { Enabled = false };

        private void OnControllerChanged(object sender, EventArgs e) => Refresh();

        public void Dispose()
        {
            controller.Changed -= OnControllerChanged;
            Menu.Dispose();
        }
    }
}
