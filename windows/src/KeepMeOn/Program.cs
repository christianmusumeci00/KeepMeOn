using System;
using System.Threading;
using System.Windows.Forms;

namespace KeepMeOn
{
    internal static class Program
    {
        private const string InstanceMutexName = @"Local\KeepMeOn.SingleInstance";

        /// <summary>Segnale con cui un secondo avvio chiede all'istanza già aperta di mostrare l'icona.</summary>
        internal const string ShowIconEventName = @"Local\KeepMeOn.ShowIcon";

        [STAThread]
        private static void Main()
        {
            using (var instance = new Mutex(true, InstanceMutexName, out bool isFirstInstance))
            {
                if (!isFirstInstance)
                {
                    SignalRunningInstance();
                    return;
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                SynchronizationContext.SetSynchronizationContext(new WindowsFormsSynchronizationContext());
                Application.Run(new TrayApp());
            }
        }

        private static void SignalRunningInstance()
        {
            try
            {
                using (var signal = EventWaitHandle.OpenExisting(ShowIconEventName))
                {
                    signal.Set();
                }
            }
            catch (WaitHandleCannotBeOpenedException)
            {
                // L'altra istanza si sta chiudendo: non c'è nulla da mostrare.
            }
        }
    }
}
