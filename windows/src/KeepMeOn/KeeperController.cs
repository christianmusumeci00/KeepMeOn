using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Windows.Forms;
using KeepMeOn.Core;
using Microsoft.Win32;
using Timer = System.Windows.Forms.Timer;

namespace KeepMeOn
{
    /// <summary>
    /// Collega impostazioni, eventi di sistema e timer, e decide quando <see cref="ActivityKeeper"/> deve agire.
    /// Un solo timer, attivo solo quando serve: si ferma se l'app è disattivata, lo schermo è bloccato,
    /// il PC è in sospensione o lo schermo è spento.
    /// </summary>
    internal sealed class KeeperController : IDisposable
    {
        /// <summary>Intervalli di controllo proposti nel menu, in secondi.</summary>
        public static readonly IReadOnlyList<int> IntervalOptions = new[] { 30, 60, 120, 240 };

        private readonly SettingsStore settings;
        private readonly SynchronizationContext ui;
        private readonly Timer timer = new Timer();
        private readonly DisplayStateWatcher displayWatcher = new DisplayStateWatcher();

        private bool isScreenLocked;
        private bool isSystemAsleep;
        private bool isDisplayOff;

        public KeeperController(SettingsStore settings)
        {
            this.settings = settings;
            ui = SynchronizationContext.Current ?? new WindowsFormsSynchronizationContext();

            timer.Tick += (sender, e) => Check();
            SystemEvents.SessionSwitch += OnSessionSwitch;
            SystemEvents.PowerModeChanged += OnPowerModeChanged;
            displayWatcher.DisplayOnChanged += (sender, isOn) =>
            {
                isDisplayOff = !isOn;
                Reconcile();
            };

            Reconcile();
        }

        /// <summary>Stato, ultimo intervento o impostazioni cambiati: il menu e l'icona si aggiornano.</summary>
        public event EventHandler Changed;

        public KeeperState State { get; private set; } = KeeperState.Off;

        public DateTime? LastIntervention { get; private set; }

        // Impostazioni, salvate nel registro.

        public bool IsEnabled
        {
            get => settings.Enabled;
            set { settings.Enabled = value; Reconcile(forceNotify: true); }
        }

        public int Interval
        {
            get => IntervalOptions.Contains(settings.IntervalSeconds) ? settings.IntervalSeconds : 60;
            set { settings.IntervalSeconds = value; Reconcile(forceNotify: true); }
        }

        public bool WorkHoursOnly
        {
            get => settings.WorkHoursOnly;
            set { settings.WorkHoursOnly = value; Reconcile(forceNotify: true); }
        }

        public WorkHours WorkHours
        {
            get => settings.WorkHours;
            set { settings.WorkHours = value; Reconcile(forceNotify: true); }
        }

        public bool LunchBreakEnabled
        {
            get => settings.LunchBreakEnabled;
            set { settings.LunchBreakEnabled = value; Reconcile(forceNotify: true); }
        }

        public LunchBreak LunchBreak
        {
            get => settings.LunchBreak;
            set { settings.LunchBreak = value; Reconcile(forceNotify: true); }
        }

        /// <summary>Soglia impostata; <see cref="Scheduler.IdleThreshold"/> la abbassa per gli intervalli lunghi.</summary>
        private double BaseIdleThreshold =>
            settings.IdleThresholdSeconds > 0 ? settings.IdleThresholdSeconds : Scheduler.DefaultIdleThresholdSeconds;

        // Timer e controllo.

        /// <summary>Riallinea timer e stato dopo ogni cambio di impostazioni o evento di sistema.</summary>
        private void Reconcile(bool forceNotify = false)
        {
            bool shouldRun = IsEnabled && !isScreenLocked && !isSystemAsleep && !isDisplayOff;
            if (!shouldRun)
            {
                timer.Stop();
            }
            else
            {
                int milliseconds = Interval * 1000;
                if (!timer.Enabled || timer.Interval != milliseconds)
                {
                    timer.Interval = milliseconds;
                    timer.Start();
                }
            }
            Check(forceNotify);
        }

        /// <summary>Aggiorna lo stato e, se l'utente è fermo da oltre la soglia, interviene.</summary>
        private void Check(bool forceNotify = false)
        {
            var newState = Scheduler.State(
                IsEnabled,
                isSystemAsleep || isDisplayOff,
                isScreenLocked,
                WorkHoursOnly,
                WorkHours,
                LunchBreakEnabled ? LunchBreak : null,
                DateTime.Now);

            bool changed = forceNotify || newState != State;
            if (newState != State)
            {
                Log.Write($"Stato: {newState}");
                State = newState;
            }

            if (newState == KeeperState.Active)
            {
                double idle = ActivityKeeper.IdleTime.TotalSeconds;
                double threshold = Scheduler.IdleThreshold(BaseIdleThreshold, Interval);
                if (Scheduler.ShouldDeclareActivity(idle, threshold))
                {
                    bool declared = ActivityKeeper.DeclareActivity();
                    bool sent = ActivityKeeper.SendNeutralInput();
                    if (declared || sent)
                    {
                        LastIntervention = DateTime.Now;
                        changed = true;
                    }
                    Log.Write($"Inattivo da {idle:0} s: sistema {(declared ? "ok" : "errore")}, segnale {(sent ? "inviato" : "non inviato")}");
                }
            }

            if (changed)
            {
                Changed?.Invoke(this, EventArgs.Empty);
            }
        }

        // Eventi di sistema: arrivano da un altro thread, si riportano su quello dell'interfaccia.

        private void OnSessionSwitch(object sender, SessionSwitchEventArgs e)
        {
            bool? locked;
            switch (e.Reason)
            {
                case SessionSwitchReason.SessionLock:
                case SessionSwitchReason.ConsoleDisconnect:
                case SessionSwitchReason.RemoteDisconnect:
                    locked = true;
                    break;
                case SessionSwitchReason.SessionUnlock:
                    locked = false;
                    break;
                default:
                    locked = null;
                    break;
            }
            if (locked is bool value)
            {
                ui.Post(_ => { isScreenLocked = value; Reconcile(); }, null);
            }
        }

        private void OnPowerModeChanged(object sender, PowerModeChangedEventArgs e)
        {
            if (e.Mode == PowerModes.Suspend)
            {
                ui.Post(_ => { isSystemAsleep = true; Reconcile(); }, null);
            }
            else if (e.Mode == PowerModes.Resume)
            {
                ui.Post(_ => { isSystemAsleep = false; Reconcile(); }, null);
            }
        }

        public void Dispose()
        {
            timer.Stop();
            timer.Dispose();
            SystemEvents.SessionSwitch -= OnSessionSwitch;
            SystemEvents.PowerModeChanged -= OnPowerModeChanged;
            displayWatcher.Dispose();
        }
    }
}
