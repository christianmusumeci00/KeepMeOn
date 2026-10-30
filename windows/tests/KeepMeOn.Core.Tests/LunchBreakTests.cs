using System;
using KeepMeOn.Core;
using Xunit;

namespace KeepMeOn.Core.Tests
{
    public class LunchBreakTests
    {
        /// <summary>Mercoledì 28 ottobre 2026.</summary>
        private static DateTime At(int hour, int minute = 0) => new DateTime(2026, 10, 28, hour, minute, 0);

        [Fact]
        public void StandardIsOneToTwo()
        {
            Assert.Equal(13 * 60, LunchBreak.Standard.StartMinute);
            Assert.Equal(14 * 60, LunchBreak.Standard.EndMinute);
            Assert.Equal("13:00–14:00", LunchBreak.Standard.Summary);
        }

        [Fact]
        public void StartIsIncludedEndIsExcluded()
        {
            var lunch = LunchBreak.Standard;
            Assert.False(lunch.Contains(At(12, 59)));
            Assert.True(lunch.Contains(At(13, 0)));
            Assert.True(lunch.Contains(At(13, 59)));
            Assert.False(lunch.Contains(At(14, 0)));
        }

        [Fact]
        public void SameStartAndEndIsEmpty()
        {
            var empty = new LunchBreak(13 * 60, 13 * 60);
            Assert.False(empty.Contains(At(13, 0)));
            Assert.False(empty.Contains(At(9)));
        }

        [Fact]
        public void OvernightBreak()
        {
            var night = new LunchBreak(23 * 60, 1 * 60);
            Assert.True(night.Contains(At(23, 30)));
            Assert.True(night.Contains(At(0, 30)));
            Assert.False(night.Contains(At(1, 0)));
            Assert.False(night.Contains(At(12)));
        }

        [Fact]
        public void ConstructorClampsInvalidValues()
        {
            var lunch = new LunchBreak(-5, 9999);
            Assert.Equal(0, lunch.StartMinute);
            Assert.Equal(1439, lunch.EndMinute);
        }
    }
}
