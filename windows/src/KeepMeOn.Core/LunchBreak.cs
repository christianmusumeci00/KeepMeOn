using System;

namespace KeepMeOn.Core
{
    /// <summary>
    /// Pausa pranzo: fascia giornaliera in cui KeepMeOn non interviene (es. 13:00–14:00).
    /// - Vale tutti i giorni.
    /// - L'inizio è incluso, la fine esclusa (13:00–14:00 vale fino alle 13:59).
    /// - Se la fine viene prima dell'inizio la pausa scavalca la mezzanotte.
    /// - Se inizio e fine coincidono la pausa è vuota.
    /// </summary>
    public sealed class LunchBreak : IEquatable<LunchBreak>
    {
        /// <summary>Predefinita: 13:00–14:00.</summary>
        public static readonly LunchBreak Standard = new LunchBreak(13 * 60, 14 * 60);

        public LunchBreak(int startMinute, int endMinute)
        {
            StartMinute = Math.Min(Math.Max(startMinute, 0), WorkHours.MinutesPerDay - 1);
            EndMinute = Math.Min(Math.Max(endMinute, 0), WorkHours.MinutesPerDay - 1);
        }

        /// <summary>Minuti dalla mezzanotte, 0…1439.</summary>
        public int StartMinute { get; }

        public int EndMinute { get; }

        /// <summary>Vero se <paramref name="date"/> (ora locale) cade nella pausa.</summary>
        public bool Contains(DateTime date)
        {
            int now = date.Hour * 60 + date.Minute;
            if (StartMinute <= EndMinute)
            {
                return now >= StartMinute && now < EndMinute;
            }
            return now >= StartMinute || now < EndMinute;
        }

        public LunchBreak WithStart(int minute) => new LunchBreak(minute, EndMinute);

        public LunchBreak WithEnd(int minute) => new LunchBreak(StartMinute, minute);

        /// <summary>Descrizione breve, es. "13:00–14:00".</summary>
        public string Summary => $"{WorkHours.TimeString(StartMinute)}–{WorkHours.TimeString(EndMinute)}";

        public bool Equals(LunchBreak other) =>
            other != null && StartMinute == other.StartMinute && EndMinute == other.EndMinute;

        public override bool Equals(object obj) => Equals(obj as LunchBreak);

        public override int GetHashCode() => (StartMinute * 397) ^ EndMinute;
    }
}
