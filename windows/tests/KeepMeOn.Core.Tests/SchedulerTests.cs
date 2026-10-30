using System;
using KeepMeOn.Core;
using Xunit;

namespace KeepMeOn.Core.Tests
{
    public class SchedulerTests
    {
        /// <summary>Mercoledì 28 ottobre 2026.</summary>
        private static DateTime Wednesday(int hour) => new DateTime(2026, 10, 28, hour, 0, 0);

        private static KeeperState State(
            bool enabled = true, bool asleep = false, bool locked = false,
            bool workHoursOnly = false, LunchBreak lunch = null, int hour = 10) =>
            Scheduler.State(enabled, asleep, locked, workHoursOnly, WorkHours.Standard, lunch, Wednesday(hour));

        [Fact]
        public void DisabledIsOffWhateverElseHappens()
        {
            Assert.Equal(KeeperState.Off, State(enabled: false));
            Assert.Equal(KeeperState.Off, State(enabled: false, asleep: true, locked: true, workHoursOnly: true, hour: 22));
        }

        [Fact]
        public void ActiveWithoutWorkHoursAtAnyTime()
        {
            Assert.Equal(KeeperState.Active, State(hour: 10));
            Assert.Equal(KeeperState.Active, State(hour: 3));
        }

        [Fact]
        public void WorkHoursOnly()
        {
            Assert.Equal(KeeperState.Active, State(workHoursOnly: true, hour: 10));
            Assert.Equal(KeeperState.PausedOutsideHours, State(workHoursOnly: true, hour: 20));
        }

        [Fact]
        public void LockAndSleepPause()
        {
            Assert.Equal(KeeperState.PausedScreenLocked, State(locked: true));
            Assert.Equal(KeeperState.PausedAsleep, State(asleep: true));
        }

        [Fact]
        public void PausePriority()
        {
            // Sospensione prima del blocco, blocco prima della fascia oraria.
            Assert.Equal(KeeperState.PausedAsleep, State(asleep: true, locked: true, workHoursOnly: true, hour: 20));
            Assert.Equal(KeeperState.PausedScreenLocked, State(locked: true, workHoursOnly: true, hour: 20));
        }

        [Fact]
        public void LunchBreakPauses()
        {
            Assert.Equal(KeeperState.PausedLunch, State(lunch: LunchBreak.Standard, hour: 13));
            Assert.Equal(KeeperState.Active, State(lunch: LunchBreak.Standard, hour: 12));
            Assert.Equal(KeeperState.Active, State(lunch: null, hour: 13));
            Assert.Equal(KeeperState.PausedLunch, State(workHoursOnly: true, lunch: LunchBreak.Standard, hour: 13));
        }

        [Fact]
        public void OutsideHoursAndLockWinOverLunch()
        {
            var lateLunch = new LunchBreak(20 * 60, 21 * 60);
            Assert.Equal(KeeperState.PausedOutsideHours, State(workHoursOnly: true, lunch: lateLunch, hour: 20));
            Assert.Equal(KeeperState.PausedScreenLocked, State(locked: true, lunch: LunchBreak.Standard, hour: 13));
        }

        [Fact]
        public void DeclaresOnlyPastThreshold()
        {
            double threshold = Scheduler.DefaultIdleThresholdSeconds;
            Assert.False(Scheduler.ShouldDeclareActivity(5, threshold));
            Assert.False(Scheduler.ShouldDeclareActivity(119.9, threshold));
            Assert.True(Scheduler.ShouldDeclareActivity(120, threshold));
            Assert.True(Scheduler.ShouldDeclareActivity(600, threshold));
        }

        [Theory]
        [InlineData(30)]
        [InlineData(60)]
        [InlineData(120)]
        public void ThresholdStaysAtBaseForShortIntervals(double interval)
        {
            Assert.Equal(120, Scheduler.IdleThreshold(120, interval));
        }

        [Fact]
        public void ThresholdDropsForLongInterval()
        {
            // 300 − 15 di margine − 240 − 24 di tolleranza.
            Assert.Equal(21, Scheduler.IdleThreshold(120, 240));
        }

        [Theory]
        [InlineData(30)]
        [InlineData(60)]
        [InlineData(120)]
        [InlineData(240)]
        public void WorstCaseIdleStaysBelowTeamsLimit(double interval)
        {
            double worstCase = Scheduler.IdleThreshold(120, interval) + interval + Scheduler.TimerToleranceSeconds(interval);
            Assert.True(worstCase < Scheduler.TeamsAwayAfterSeconds);
        }

        [Fact]
        public void ThresholdNeverNegative()
        {
            Assert.Equal(0, Scheduler.IdleThreshold(120, 600));
        }
    }
}
