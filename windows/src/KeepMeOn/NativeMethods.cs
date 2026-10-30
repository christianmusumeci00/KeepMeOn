using System;
using System.Runtime.InteropServices;

namespace KeepMeOn
{
    /// <summary>Funzioni di Windows usate da KeepMeOn.</summary>
    internal static class NativeMethods
    {
        // Inattività.

        [StructLayout(LayoutKind.Sequential)]
        internal struct LASTINPUTINFO
        {
            public uint cbSize;
            public uint dwTime;
        }

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

        // Input sintetico.

        internal const uint INPUT_MOUSE = 0;
        internal const uint INPUT_KEYBOARD = 1;
        internal const uint MOUSEEVENTF_MOVE = 0x0001;
        internal const uint KEYEVENTF_KEYUP = 0x0002;

        [StructLayout(LayoutKind.Sequential)]
        internal struct MOUSEINPUT
        {
            public int dx;
            public int dy;
            public uint mouseData;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct KEYBDINPUT
        {
            public ushort wVk;
            public ushort wScan;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct HARDWAREINPUT
        {
            public uint uMsg;
            public ushort wParamL;
            public ushort wParamH;
        }

        /// <summary>L'unione deve avere la dimensione del membro più grande (MOUSEINPUT), a 32 e a 64 bit.</summary>
        [StructLayout(LayoutKind.Explicit)]
        internal struct InputUnion
        {
            [FieldOffset(0)] public MOUSEINPUT mi;
            [FieldOffset(0)] public KEYBDINPUT ki;
            [FieldOffset(0)] public HARDWAREINPUT hi;
        }

        [StructLayout(LayoutKind.Sequential)]
        internal struct INPUT
        {
            public uint type;
            public InputUnion u;
        }

        [DllImport("user32.dll", SetLastError = true)]
        internal static extern uint SendInput(uint nInputs, [In] INPUT[] pInputs, int cbSize);

        [StructLayout(LayoutKind.Sequential)]
        internal struct POINT
        {
            public int X;
            public int Y;
        }

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetCursorPos(out POINT point);

        // Sospensione e schermo.

        internal const uint ES_SYSTEM_REQUIRED = 0x00000001;
        internal const uint ES_DISPLAY_REQUIRED = 0x00000002;

        [DllImport("kernel32.dll")]
        internal static extern uint SetThreadExecutionState(uint esFlags);

        internal const int WM_POWERBROADCAST = 0x0218;
        internal const int PBT_POWERSETTINGCHANGE = 0x8013;
        internal const int DEVICE_NOTIFY_WINDOW_HANDLE = 0;

        /// <summary>GUID_CONSOLE_DISPLAY_STATE: schermo acceso, spento o attenuato.</summary>
        internal static readonly Guid ConsoleDisplayState = new Guid("6FE69556-704A-47A0-8F24-C28D936FDA47");

        [DllImport("user32.dll", SetLastError = true)]
        internal static extern IntPtr RegisterPowerSettingNotification(IntPtr hRecipient, ref Guid powerSettingGuid, int flags);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool UnregisterPowerSettingNotification(IntPtr handle);
    }
}
