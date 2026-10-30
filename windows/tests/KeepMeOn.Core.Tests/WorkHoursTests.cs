using System;
using System.Collections.Generic;
using KeepMeOn.Core;
using Xunit;

namespace KeepMeOn.Core.Tests
{
    public class WorkHoursTests
    {
        /// <summary>Settimana di riferimento: lunedì 26 ottobre … domenica 1 novembre 2026.</summary>
        private static DateTime At(string day, int hour, int minute = 0)
        {
            var days = new Dictionary<string, (int Month, int Day)>
            {
                ["lun"] = (10, 26), ["mar"] = (10, 27), ["mer"] = (10, 28), ["gio"] = (10, 29),
                ["ven"] = (10, 30), ["sab"] = (10, 31), ["dom"] = (11, 1),
            };
            var (month, dayOfMonth) = days[day];
            return new DateTime(2026, month, dayOfMonth, hour, minute, 0);
        }

        [Fact]
        public void ReferenceWeekStartsOnMonday()
        {
            Assert.Equal(2, WorkHours.WeekdayOf(At("lun", 12)));
            Assert.Equal(1, WorkHours.WeekdayOf(At("dom", 12)));
        }

        [Fact]
        public void StandardIsMondayToFridayNineToSix()
        {
            Assert.Equal(540, WorkHours.Standard.StartMinute);
            Assert.Equal(1080, WorkHours.Standard.EndMinute);
            Assert.Equal(new[] { 2, 3, 4, 5, 6 }, WorkHours.Standard.Weekdays);
        }

        [Fact]
        public void StartIsIncludedEndIsExcluded()
        {
            var hours = WorkHours.Standard;
            Assert.False(hours.Contains(At("lun", 8, 59)));
            Assert.True(hours.Contains(At("lun", 9, 0)));
            Assert.True(hours.Contains(At("lun", 17, 59)));
            Assert.False(hours.Contains(At("lun", 18, 0)));
        }

        [Fact]
        public void WeekendIsExcluded()
        {
            Assert.False(WorkHours.Standard.Contains(At("sab", 10)));
            Assert.False(WorkHours.Standard.Contains(At("dom", 10)));
        }

        [Fact]
        public void OvernightRangeBelongsToTheDayItStarts()
        {
            var night = new WorkHours(22 * 60, 6 * 60, new[] { 2, 3, 4, 5, 6 });
            Assert.True(night.Contains(At("ven", 23)));
            Assert.True(night.Contains(At("sab", 3)));   // turno iniziato venerdì
            Assert.False(night.Contains(At("sab", 23)));
            Assert.False(night.Contains(At("lun", 3)));  // domenica non è selezionata
            Assert.True(night.Contains(At("mar", 3)));
            Assert.False(night.Contains(At("mar", 6)));  // la fine è esclusa
            Assert.False(night.Contains(At("mar", 12)));
        }

        [Fact]
        public void SameStartAndEndCoversWholeDay()
        {
            var allDay = new WorkHours(0, 0, new[] { 7 });
            Assert.True(allDay.Contains(At("sab", 0)));
            Assert.True(allDay.Contains(At("sab", 23, 59)));
            Assert.False(allDay.Contains(At("ven", 12)));
        }

        [Fact]
        public void NoWeekdaysIsNeverActive()
        {
            var none = new WorkHours(540, 1080, Array.Empty<int>());
            foreach (var day in new[] { "lun", "mer", "sab", "dom" })
            {
                Assert.False(none.Contains(At(day, 12)));
            }
        }

        [Fact]
        public void ConstructorClampsInvalidValues()
        {
            var hours = new WorkHours(-10, 5000, new[] { 0, 2, 8 });
            Assert.Equal(0, hours.StartMinute);
            Assert.Equal(1439, hours.EndMinute);
            Assert.Equal(new[] { 2 }, hours.Weekdays);
        }

        [Fact]
        public void WeekdayMaskRoundTrip()
        {
            Assert.Equal(0b0111110, WorkHours.Standard.WeekdayMask);
            Assert.Equal(WorkHours.Standard, WorkHours.FromMask(540, 1080, WorkHours.Standard.WeekdayMask));
            var weekend = new WorkHours(0, 0, new[] { 1, 7 });
            Assert.Equal(weekend, WorkHours.FromMask(0, 0, weekend.WeekdayMask));
        }

        [Fact]
        public void WithMethodsReturnUpdatedCopies()
        {
            var hours = WorkHours.Standard.WithStart(8 * 60).WithEnd(17 * 60).WithDay(7, true).WithDay(2, false);
            Assert.Equal(480, hours.StartMinute);
            Assert.Equal(1020, hours.EndMinute);
            Assert.True(hours.IncludesDay(7));
            Assert.False(hours.IncludesDay(2));
            Assert.Equal(540, WorkHours.Standard.StartMinute); // l'originale non cambia
        }

        [Fact]
        public void Summary()
        {
            Assert.Equal("lun–ven, 09:00–18:00", WorkHours.Standard.Summary);
            Assert.Equal("lun, mer, ven, 08:30–13:00", new WorkHours(8 * 60 + 30, 13 * 60, new[] { 2, 4, 6 }).Summary);
            Assert.Equal("tutti i giorni, tutto il giorno", new WorkHours(0, 0, new[] { 1, 2, 3, 4, 5, 6, 7 }).Summary);
            Assert.Equal("sab, dom, 22:00–06:00", new WorkHours(22 * 60, 6 * 60, new[] { 7, 1 }).Summary);
            Assert.Equal("nessun giorno, 09:00–18:00", new WorkHours(540, 1080, Array.Empty<int>()).Summary);
        }
    }
}
