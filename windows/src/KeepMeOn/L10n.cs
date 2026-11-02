using System;
using KeepMeOn.Core;

namespace KeepMeOn
{
    /// <summary>
    /// Lingua dell'interfaccia in uso. I testi stanno nel codice, le due versioni una accanto all'altra:
    /// <c>L10n.T("Settings", "Impostazioni")</c>.
    /// </summary>
    internal static class L10n
    {
        public static Language Current { get; private set; } = Languages.Default;

        /// <summary>Lingua cambiata: menu e finestre aperte si ricostruiscono.</summary>
        public static event EventHandler Changed;

        public static string T(string english, string italian) => Current.Pick(english, italian);

        public static void Set(Language language)
        {
            if (language == Current)
            {
                return;
            }
            Current = language;
            Changed?.Invoke(null, EventArgs.Empty);
        }
    }
}
