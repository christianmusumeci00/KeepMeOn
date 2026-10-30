using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using static KeepMeOn.NativeMethods;

namespace KeepMeOn
{
    /// <summary>
    /// Avvisa quando lo schermo si spegne o si riaccende. Con lo schermo spento KeepMeOn
    /// si ferma, altrimenti il suo segnale lo riaccenderebbe.
    /// </summary>
    internal sealed class DisplayStateWatcher : NativeWindow, IDisposable
    {
        private IntPtr registration;

        public DisplayStateWatcher()
        {
            CreateHandle(new CreateParams());
            var setting = ConsoleDisplayState;
            registration = RegisterPowerSettingNotification(Handle, ref setting, DEVICE_NOTIFY_WINDOW_HANDLE);
        }

        /// <summary>true quando lo schermo è acceso (anche attenuato), false quando è spento.</summary>
        public event EventHandler<bool> DisplayOnChanged;

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_POWERBROADCAST && m.WParam.ToInt64() == PBT_POWERSETTINGCHANGE && m.LParam != IntPtr.Zero)
            {
                // POWERBROADCAST_SETTING: GUID (16 byte), lunghezza (4 byte), dato: 0 spento, 1 acceso, 2 attenuato.
                int state = Marshal.ReadInt32(m.LParam, 20);
                DisplayOnChanged?.Invoke(this, state != 0);
            }
            base.WndProc(ref m);
        }

        public void Dispose()
        {
            if (registration != IntPtr.Zero)
            {
                UnregisterPowerSettingNotification(registration);
                registration = IntPtr.Zero;
            }
            DestroyHandle();
        }
    }
}
