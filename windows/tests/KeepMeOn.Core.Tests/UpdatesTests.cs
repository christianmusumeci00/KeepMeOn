using System;
using KeepMeOn.Core;
using Xunit;

namespace KeepMeOn.Core.Tests
{
    public class UpdatesTests
    {
        /// <summary>Estratto di una risposta reale di GitHub (campi usati dall'app più qualche altro).</summary>
        private const string SampleJson = @"{
          ""tag_name"": ""v1.2.0"",
          ""name"": ""KeepMeOn 1.2.0"",
          ""html_url"": ""https://github.com/christianmusumeci00/KeepMeOn/releases/tag/v1.2.0"",
          ""draft"": false,
          ""prerelease"": false,
          ""assets"": [
            {""name"": ""KeepMeOn.dmg"", ""size"": 876543,
             ""browser_download_url"": ""https://github.com/christianmusumeci00/KeepMeOn/releases/download/v1.2.0/KeepMeOn.dmg""},
            {""name"": ""KeepMeOn-Setup.exe"", ""size"": 2262094,
             ""browser_download_url"": ""https://github.com/christianmusumeci00/KeepMeOn/releases/download/v1.2.0/KeepMeOn-Setup.exe""}
          ]
        }";

        private static AppVersion V(string text) => AppVersion.Parse(text);

        [Fact]
        public void ParsesVersions()
        {
            Assert.Equal(new[] { 1, 2, 0 }, V("1.2.0").Components);
            Assert.Equal(new[] { 1, 10 }, V("v1.10").Components);
            Assert.Equal(new[] { 2, 0, 1 }, V(" V2.0.1-beta ").Components);
            Assert.Null(V(""));
            Assert.Null(V("windows-v1.0.0-prova1"));
            Assert.Null(V("1..2"));
            Assert.Equal("1.2.0", V("1.2.0").ToString());
            Assert.Equal("1.1.0", AppVersion.FromSystemVersion(new Version(1, 1, 0, 0)).ToString());
        }

        [Fact]
        public void ComparesVersions()
        {
            Assert.True(V("1.1.0").CompareTo(V("1.2.0")) < 0);
            Assert.True(V("1.9.0").CompareTo(V("1.10.0")) < 0);
            Assert.True(V("1.2").CompareTo(V("1.2.1")) < 0);
            Assert.Equal(V("1.2"), V("v1.2.0"));
            Assert.Equal(V("1.2").GetHashCode(), V("v1.2.0").GetHashCode());
            Assert.True(V("2.0.0").CompareTo(V("1.99.99")) > 0);
        }

        [Fact]
        public void ParsesRelease()
        {
            var release = ReleaseInfo.Parse(SampleJson);
            Assert.Equal("v1.2.0", release.TagName);
            Assert.Equal(V("1.2.0"), release.Version);
            Assert.Equal("https://github.com/christianmusumeci00/KeepMeOn/releases/tag/v1.2.0", release.PageUrl);
            Assert.Equal(2262094, release.Asset("KeepMeOn-Setup.exe").Size);
            Assert.EndsWith("/KeepMeOn.dmg", release.Asset("KeepMeOn.dmg").DownloadUrl);
            Assert.Null(release.Asset("altro.zip"));
        }

        [Fact]
        public void AvailableUpdateOnlyWhenNewerAndFilePresent()
        {
            var release = ReleaseInfo.Parse(SampleJson);
            Assert.NotNull(UpdatePolicy.AvailableUpdate(release, V("1.1.0"), "KeepMeOn-Setup.exe"));
            Assert.Null(UpdatePolicy.AvailableUpdate(release, V("1.2.0"), "KeepMeOn-Setup.exe"));
            Assert.Null(UpdatePolicy.AvailableUpdate(release, V("1.3.0"), "KeepMeOn-Setup.exe"));
            Assert.Null(UpdatePolicy.AvailableUpdate(release, V("1.1.0"), "altro.zip"));
        }

        [Fact]
        public void CheckIsDueOncePerDay()
        {
            var now = new DateTime(2026, 10, 30, 15, 0, 0);
            Assert.True(UpdatePolicy.IsCheckDue(null, now));
            Assert.False(UpdatePolicy.IsCheckDue(now.AddHours(-1), now));
            Assert.True(UpdatePolicy.IsCheckDue(now.AddHours(-25), now));
            // Un orologio spostato indietro non deve bloccare i controlli.
            Assert.True(UpdatePolicy.IsCheckDue(now.AddHours(1), now));
        }
    }
}
