using System;
using System.Runtime.InteropServices;
using static KeepMeOn.NativeMethods;

namespace KeepMeOn
{
    /// <summary>
    /// Unico punto di contatto con Windows per tenere "presente" l'utente.
    ///
    /// Usa due meccanismi complementari, come la versione per Mac:
    /// - <c>SetThreadExecutionState</c> rimanda sospensione e spegnimento dello schermo,
    ///   ma non azzera il contatore di inattività che legge Teams (<c>GetLastInputInfo</c>);
    /// - un input neutro azzera quel contatore. Non muove il cursore, non scrive e non clicca.
    /// Su Windows non serve nessun permesso.
    /// </summary>
    internal static class ActivityKeeper
    {
        /// <summary>Marca gli input inviati da KeepMeOn ("KMON"), così si riconoscono in un hook.</summary>
        private static readonly IntPtr Marker = new IntPtr(0x4B4D4F4E);

        /// <summary>Tasto virtuale che Windows non assegna a nulla (0x97–0x9F sono liberi).</summary>
        private const ushort UnassignedKey = 0x97;

        /// <summary>Tempo trascorso dall'ultimo input (mouse, tastiera, touch), per tutto il sistema.</summary>
        public static TimeSpan IdleTime
        {
            get
            {
                var info = new LASTINPUTINFO { cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO)) };
                if (!GetLastInputInfo(ref info))
                {
                    return TimeSpan.Zero;
                }
                // Aritmetica senza segno: resta corretta anche quando il contatore riparte da zero (ogni 49 giorni).
                uint idleMilliseconds = unchecked((uint)Environment.TickCount - info.dwTime);
                return TimeSpan.FromMilliseconds(idleMilliseconds);
            }
        }

        /// <summary>Rimanda sospensione e spegnimento dello schermo, come se l'utente fosse presente.</summary>
        public static bool DeclareActivity() => SetThreadExecutionState(ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED) != 0;

        /// <summary>Input neutro usato dall'app: il rilascio di un tasto che non esiste.</summary>
        public static bool SendNeutralInput() => SendUnassignedKeyUp();

        /// <summary>
        /// Comunica il rilascio di un tasto non assegnato e mai premuto: nessuna app ci reagisce,
        /// ma per Windows è un input e il contatore di inattività riparte.
        /// </summary>
        internal static bool SendUnassignedKeyUp()
        {
            var input = new INPUT
            {
                type = INPUT_KEYBOARD,
                u = new InputUnion { ki = new KEYBDINPUT { wVk = UnassignedKey, dwFlags = KEYEVENTF_KEYUP, dwExtraInfo = Marker } },
            };
            return Send(input);
        }

        /// <summary>Alternativa: uno spostamento del mouse di 0 pixel. Il cursore resta fermo.</summary>
        internal static bool SendZeroMouseMove()
        {
            var input = new INPUT
            {
                type = INPUT_MOUSE,
                u = new InputUnion { mi = new MOUSEINPUT { dx = 0, dy = 0, dwFlags = MOUSEEVENTF_MOVE, dwExtraInfo = Marker } },
            };
            return Send(input);
        }

        private static bool Send(INPUT input) =>
            SendInput(1, new[] { input }, Marshal.SizeOf(typeof(INPUT))) == 1;
    }
}
