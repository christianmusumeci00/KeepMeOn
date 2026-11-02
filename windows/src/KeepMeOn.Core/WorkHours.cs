using System;
using System.Collections.Generic;
using System.Linq;

namespace KeepMeOn.Core
{
    /// <summary>
    /// Fascia oraria di lavoro: ora di inizio, ora di fine e giorni della settimana.
    /// Stesse regole della versione per Mac:
    /// - i giorni sono numerati 1 = domenica … 7 = sabato;
    /// - l'inizio è incluso, la fine esclusa (09:00–18:00 vale fino alle 17:59);
    /// - se la fine viene prima dell'inizio la fascia scavalca la mezzanotte
    ///   e la parte dopo mezzanotte conta per il giorno in cui è iniziata;
    /// - se inizio e fine coincidono la fascia copre l'intera giornata.
    /// </summary>
    public sealed class WorkHours : IEquatable<WorkHours>
    {
        public const int MinutesPerDay = 24 * 60;

        /// <summary>Ordine di visualizzazione dei giorni, da lunedì a domenica.</summary>
        public static readonly IReadOnlyList<int> MondayFirst = new[] { 2, 3, 4, 5, 6, 7, 1 };

        private static readonly string[] EnglishShortNames = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
        private static readonly string[] ItalianShortNames = { "dom", "lun", "mar", "mer", "gio", "ven", "sab" };

        /// <summary>Predefinita: lunedì–venerdì, 09:00–18:00.</summary>
        public static readonly WorkHours Standard = new WorkHours(9 * 60, 18 * 60, new[] { 2, 3, 4, 5, 6 });

        private readonly HashSet<int> weekdays;

        public WorkHours(int startMinute, int endMinute, IEnumerable<int> weekdays)
        {
            StartMinute = Clamp(startMinute);
            EndMinute = Clamp(endMinute);
            this.weekdays = new HashSet<int>(weekdays.Where(day => day >= 1 && day <= 7));
        }

        /// <summary>Minuti dalla mezzanotte, 0…1439.</summary>
        public int StartMinute { get; }

        public int EndMinute { get; }

        public IReadOnlyCollection<int> Weekdays => weekdays;

        /// <summary>Giorni come bitmask (bit 0 = domenica … bit 6 = sabato), comoda da salvare.</summary>
        public int WeekdayMask => weekdays.Aggregate(0, (mask, day) => mask | (1 << (day - 1)));

        public static WorkHours FromMask(int startMinute, int endMinute, int weekdayMask) =>
            new WorkHours(startMinute, endMinute, Enumerable.Range(1, 7).Where(day => (weekdayMask & (1 << (day - 1))) != 0));

        /// <summary>Giorno della settimana di <paramref name="date"/>, numerato 1 = domenica … 7 = sabato.</summary>
        public static int WeekdayOf(DateTime date) => (int)date.DayOfWeek + 1;

        public bool IncludesDay(int weekday) => weekdays.Contains(weekday);

        /// <summary>Vero se <paramref name="date"/> (ora locale) cade nella fascia.</summary>
        public bool Contains(DateTime date)
        {
            int weekday = WeekdayOf(date);
            int now = date.Hour * 60 + date.Minute;

            if (StartMinute == EndMinute)
            {
                return weekdays.Contains(weekday);
            }
            if (StartMinute < EndMinute)
            {
                return weekdays.Contains(weekday) && now >= StartMinute && now < EndMinute;
            }
            // Fascia a cavallo della mezzanotte.
            if (now >= StartMinute)
            {
                return weekdays.Contains(weekday);
            }
            if (now < EndMinute)
            {
                return weekdays.Contains(weekday == 1 ? 7 : weekday - 1);
            }
            return false;
        }

        public WorkHours WithStart(int minute) => new WorkHours(minute, EndMinute, weekdays);

        public WorkHours WithEnd(int minute) => new WorkHours(StartMinute, minute, weekdays);

        public WorkHours WithDay(int weekday, bool included) =>
            new WorkHours(StartMinute, EndMinute, included ? weekdays.Append(weekday) : weekdays.Where(day => day != weekday));

        public static string ShortName(int weekday, Language language) =>
            (language == Language.Italian ? ItalianShortNames : EnglishShortNames)[weekday - 1];

        public static string TimeString(int minute) => $"{minute / 60:00}:{minute % 60:00}";

        /// <summary>Descrizione breve, es. "Mon–Fri, 09:00–18:00" o "lun–ven, 09:00–18:00".</summary>
        public string Summary(Language language) => $"{DaysSummary(language)}, {HoursSummary(language)}";

        internal string DaysSummary(Language language)
        {
            var days = MondayFirst.Where(weekdays.Contains).ToList();
            if (days.Count == 0) return language.Pick("no days", "nessun giorno");
            if (days.Count == 7) return language.Pick("every day", "tutti i giorni");

            // Tre o più giorni consecutivi diventano un intervallo ("lun–ven").
            var positions = days.Select(day => MondayFirst.ToList().IndexOf(day)).ToList();
            bool isRun = positions[positions.Count - 1] - positions[0] == positions.Count - 1;
            if (isRun && days.Count >= 3)
            {
                return $"{ShortName(days[0], language)}–{ShortName(days[days.Count - 1], language)}";
            }
            return string.Join(", ", days.Select(day => ShortName(day, language)));
        }

        internal string HoursSummary(Language language) =>
            StartMinute == EndMinute ? language.Pick("all day", "tutto il giorno") : $"{TimeString(StartMinute)}–{TimeString(EndMinute)}";

        public bool Equals(WorkHours other) =>
            other != null && StartMinute == other.StartMinute && EndMinute == other.EndMinute && weekdays.SetEquals(other.weekdays);

        public override bool Equals(object obj) => Equals(obj as WorkHours);

        public override int GetHashCode() => (StartMinute * 397) ^ (EndMinute * 31) ^ WeekdayMask;

        private static int Clamp(int minute) => Math.Min(Math.Max(minute, 0), MinutesPerDay - 1);
    }
}
