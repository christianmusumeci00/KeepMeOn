using KeepMeOn.Core;
using Xunit;

namespace KeepMeOn.Core.Tests
{
    public class LanguageTests
    {
        [Fact]
        public void DefaultIsEnglish()
        {
            Assert.Equal(Language.English, Languages.Default);
        }

        [Fact]
        public void CodesRoundTrip()
        {
            foreach (var language in Languages.All)
            {
                Assert.Equal(language, Languages.FromCode(language.Code()));
            }
            Assert.Equal("en", Language.English.Code());
            Assert.Equal("it", Language.Italian.Code());
        }

        [Fact]
        public void FromCodeAcceptsRegionsAndRejectsUnknown()
        {
            Assert.Equal(Language.Italian, Languages.FromCode("it-IT"));
            Assert.Equal(Language.English, Languages.FromCode("EN_us"));
            Assert.Null(Languages.FromCode("fr"));
            Assert.Null(Languages.FromCode(""));
            Assert.Null(Languages.FromCode(null));
        }

        [Fact]
        public void Pick()
        {
            Assert.Equal("Settings", Language.English.Pick("Settings", "Impostazioni"));
            Assert.Equal("Impostazioni", Language.Italian.Pick("Settings", "Impostazioni"));
        }
    }
}
