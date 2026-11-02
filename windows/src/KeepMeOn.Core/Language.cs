using System;
using System.Collections.Generic;

namespace KeepMeOn.Core
{
    /// <summary>Lingua dell'interfaccia. Si sceglie nell'installer, nella configurazione guidata e nelle impostazioni.</summary>
    public enum Language
    {
        English,
        Italian,
    }

    public static class Languages
    {
        /// <summary>Predefinita per le nuove installazioni.</summary>
        public const Language Default = Language.English;

        public static readonly IReadOnlyList<Language> All = new[] { Language.English, Language.Italian };

        /// <summary>Codice salvato nel registro e usato dall'installer: "en" o "it".</summary>
        public static string Code(this Language language) => language == Language.Italian ? "it" : "en";

        /// <summary>Lingua di un codice ("it", "it-IT", "en"…); null se il codice è vuoto o sconosciuto.</summary>
        public static Language? FromCode(string code)
        {
            if (string.IsNullOrEmpty(code)) return null;
            string prefix = code.Split('-', '_')[0];
            if (prefix.Equals("en", StringComparison.OrdinalIgnoreCase)) return Language.English;
            if (prefix.Equals("it", StringComparison.OrdinalIgnoreCase)) return Language.Italian;
            return null;
        }

        /// <summary>Nome della lingua scritto nella lingua stessa, come si usa nei selettori.</summary>
        public static string DisplayName(this Language language) => language == Language.Italian ? "Italiano" : "English";

        /// <summary>Il testo nella lingua giusta: <c>language.Pick("Settings", "Impostazioni")</c>.</summary>
        public static string Pick(this Language language, string english, string italian) =>
            language == Language.Italian ? italian : english;
    }
}
