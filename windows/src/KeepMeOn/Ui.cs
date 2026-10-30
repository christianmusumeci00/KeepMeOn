using System.Drawing;
using System.Windows.Forms;

namespace KeepMeOn
{
    /// <summary>Elementi comuni alle finestre: icone incorporate, colori e testi a capo automatico.</summary>
    internal static class Ui
    {
        public static readonly Color SecondaryText = Color.FromArgb(90, 90, 90);
        public static readonly Color CardBackground = Color.FromArgb(238, 246, 230);

        /// <summary>Icona incorporata (cartella Resources), nella dimensione più vicina a <paramref name="size"/>.</summary>
        public static Icon LoadIcon(string name, Size size)
        {
            using (var stream = typeof(Ui).Assembly.GetManifestResourceStream(name + ".ico"))
            {
                return new Icon(stream, size);
            }
        }

        public static Icon AppIcon() => LoadIcon("AppIcon", new Size(32, 32));

        public static Font Bold(Font font, float size) => new Font(font.FontFamily, size, FontStyle.Bold);

        /// <summary>Testo che va a capo entro <paramref name="width"/> pixel (a 96 DPI).</summary>
        public static Label Paragraph(string text, int width, Color? color = null, Padding? margin = null) => new Label
        {
            Text = text,
            AutoSize = true,
            MaximumSize = new Size(width, 0),
            ForeColor = color ?? SystemColors.ControlText,
            Margin = margin ?? new Padding(0, 2, 0, 0),
        };

        public static Label Heading(string text, Font baseFont, Padding margin) => new Label
        {
            Text = text,
            AutoSize = true,
            Font = Bold(baseFont, baseFont.SizeInPoints),
            Margin = margin,
        };
    }
}
