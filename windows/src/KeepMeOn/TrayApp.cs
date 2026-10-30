using System;
using System.Drawing;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;
using KeepMeOn.Core;

namespace KeepMeOn
{
    /// <summary>
    /// L'app vive nell'area di notifica: nessuna finestra principale, nessuna voce sulla barra delle applicazioni.
    /// L'icona è grigia se l'app è spenta, una tazzina se è accesa ma in pausa, la tazzina con la spunta
    /// quando sta davvero tenendo verde lo stato.
    /// </summary>
    internal sealed class TrayApp : ApplicationContext
    {
        private readonly SettingsStore settings = new SettingsStore();
        private readonly SynchronizationContext ui = SynchronizationContext.Current;
        private readonly KeeperController controller;
        private readonly TrayMenu menu;
        private readonly NotifyIcon notifyIcon;
        private readonly Icon coveringIcon;
        private readonly Icon pausedIcon;
        private readonly Icon offIcon;
        private readonly EventWaitHandle showIconSignal;
        private readonly RegisteredWaitHandle showIconWait;
        private WelcomeForm welcomeForm;
        private SettingsForm settingsForm;

        public TrayApp()
        {
            Log.Write("Avvio");
            controller = new KeeperController(settings);

            Size size = SystemInformation.SmallIconSize;
            coveringIcon = Ui.LoadIcon("TrayCovering", size);
            pausedIcon = Ui.LoadIcon("TrayPaused", size);
            offIcon = Ui.LoadIcon("TrayOff", size);

            menu = new TrayMenu(controller);
            menu.SettingsRequested += (sender, e) => ShowSettings();
            menu.HideIconRequested += (sender, e) => HideIcon();
            menu.WelcomeRequested += (sender, e) => ShowWelcome();
            menu.ExitRequested += (sender, e) => ExitThread();

            notifyIcon = new NotifyIcon { ContextMenuStrip = menu.Menu };
            notifyIcon.MouseUp += OnTrayMouseUp;
            controller.Changed += (sender, e) => RefreshIcon();
            RefreshIcon();
            notifyIcon.Visible = settings.ShowTrayIcon;

            // Un secondo avvio (menu Start, Esplora file) chiede a questa istanza di mostrare l'icona.
            showIconSignal = new EventWaitHandle(false, EventResetMode.AutoReset, Program.ShowIconEventName);
            showIconWait = ThreadPool.RegisterWaitForSingleObject(
                showIconSignal, (state, timedOut) => ui.Post(_ => ShowIcon(), null), null, Timeout.Infinite, false);

            if (!settings.WelcomeCompleted)
            {
                ui.Post(_ => ShowWelcome(), null);
            }
        }

        private void RefreshIcon()
        {
            if (!controller.IsEnabled)
            {
                notifyIcon.Icon = offIcon;
            }
            else
            {
                notifyIcon.Icon = controller.State == KeeperState.Active ? coveringIcon : pausedIcon;
            }
            // Windows accetta al massimo 63 caratteri nel suggerimento dell'icona.
            string text = "KeepMeOn – " + TrayMenu.StatusText(controller.State, controller.Interval);
            notifyIcon.Text = text.Length > 63 ? text.Substring(0, 63) : text;
        }

        private void OnTrayMouseUp(object sender, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left)
            {
                return;
            }
            // Anche il clic sinistro apre il menu. NotifyIcon lo fa da sé solo con il destro:
            // si usa il suo metodo interno, che posiziona il menu come farebbe Windows.
            typeof(NotifyIcon)
                .GetMethod("ShowContextMenu", BindingFlags.Instance | BindingFlags.NonPublic)
                ?.Invoke(notifyIcon, null);
        }

        private void ShowIcon()
        {
            settings.ShowTrayIcon = true;
            notifyIcon.Visible = true;
        }

        private void HideIcon()
        {
            var answer = MessageBox.Show(
                "KeepMeOn continuerà a funzionare senza nulla di visibile. Per far ricomparire l'icona riapri KeepMeOn dal menu Start.",
                "Nascondere l'icona?",
                MessageBoxButtons.OKCancel,
                MessageBoxIcon.Question);
            if (answer == DialogResult.OK)
            {
                settings.ShowTrayIcon = false;
                notifyIcon.Visible = false;
            }
        }

        private void ShowWelcome()
        {
            if (welcomeForm == null || welcomeForm.IsDisposed)
            {
                welcomeForm = new WelcomeForm();
                welcomeForm.SettingsRequested += (sender, e) => ShowSettings();
                welcomeForm.FormClosed += (sender, e) => settings.WelcomeCompleted = true;
            }
            BringToFront(welcomeForm);
        }

        private void ShowSettings()
        {
            if (settingsForm == null || settingsForm.IsDisposed)
            {
                settingsForm = new SettingsForm(controller);
            }
            BringToFront(settingsForm);
        }

        private static void BringToFront(Form form)
        {
            form.Show();
            if (form.WindowState == FormWindowState.Minimized)
            {
                form.WindowState = FormWindowState.Normal;
            }
            form.Activate();
        }

        protected override void ExitThreadCore()
        {
            Log.Write("Uscita");
            showIconWait.Unregister(null);
            showIconSignal.Dispose();
            welcomeForm?.Close();
            settingsForm?.Close();
            notifyIcon.Visible = false;
            notifyIcon.Dispose();
            menu.Dispose();
            controller.Dispose();
            base.ExitThreadCore();
        }
    }
}
