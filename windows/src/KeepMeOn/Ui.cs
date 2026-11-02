using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using KeepMeOn.Core;

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

        /// <summary>«Language:» e la scelta della lingua: nelle impostazioni e nella configurazione guidata.</summary>
        public static FlowLayoutPanel LanguagePicker(Padding margin)
        {
            var panel = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = margin };
            panel.Controls.Add(new Label { Text = L10n.T("Language:", "Lingua:"), AutoSize = true, Margin = new Padding(0, 6, 6, 0) });
            var choice = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 110, Margin = Padding.Empty };
            choice.Items.AddRange(Languages.All.Select(language => (object)language.DisplayName()).ToArray());
            choice.SelectedIndex = Languages.All.ToList().IndexOf(L10n.Current);
            // Cambio rinviato: chi ascolta L10n.Changed ricostruisce la finestra, compresa questa casella.
            choice.SelectedIndexChanged += (sender, e) =>
            {
                var language = Languages.All[choice.SelectedIndex];
                choice.BeginInvoke((Action)(() => L10n.Set(language)));
            };
            panel.Controls.Add(choice);
            return panel;
        }

        public static Label Heading(string text, Font baseFont, Padding margin) => new Label
        {
            Text = text,
            AutoSize = true,
            Font = Bold(baseFont, baseFont.SizeInPoints),
            Margin = margin,
        };
    }
}
