using System;
using System.Drawing;
using System.Windows.Forms;

namespace KeepMeOn
{
    /// <summary>Schermata di benvenuto: a cosa serve KeepMeOn e come funziona. Su Windows non servono permessi.</summary>
    internal sealed class WelcomeForm : Form
    {
        private const int ContentWidth = 470;

        private static readonly (string Title, string Text)[] Features =
        {
            ("Pause brevi, stato verde",
             "Interviene solo dopo 2 minuti in cui non usi il PC: mentre lavori non fa nulla."),
            ("Non tocca niente",
             "Non muove il mouse, non preme tasti e non clicca: invia soltanto un segnale neutro al sistema."),
            ("Si ferma da sola",
             "Con lo schermo bloccato, con il PC in sospensione o lo schermo spento, fuori dall'orario di lavoro e durante la pausa pranzo."),
            ("Via per più tempo?",
             "Blocca il PC con Windows+L: KeepMeOn si mette in pausa e Teams mostra correttamente che sei assente."),
        };

        public WelcomeForm()
        {
            SuspendLayout();
            AutoScaleDimensions = new SizeF(96F, 96F);
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = SystemFonts.MessageBoxFont;
            Text = "Benvenuto in KeepMeOn";
            Icon = Ui.AppIcon();
            BackColor = SystemColors.Window;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            AutoSize = true;
            AutoSizeMode = AutoSizeMode.GrowAndShrink;

            var content = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink,
                Padding = new Padding(28, 24, 28, 20),
            };

            content.Controls.Add(Header());
            content.Controls.Add(Ui.Paragraph(
                "Ti alzi per un caffè, rispondi al telefono o vai a ritirare una stampa: dopo pochi minuti senza mouse e tastiera Teams ti segna «Assente», anche se stai per tornare. KeepMeOn tiene il PC sveglio durante queste brevi pause, così resti verde e i colleghi sanno che sei raggiungibile.",
                ContentWidth, margin: new Padding(0, 18, 0, 4)));

            foreach (var feature in Features)
            {
                content.Controls.Add(Ui.Heading(feature.Title, Font, new Padding(0, 12, 0, 0)));
                content.Controls.Add(Ui.Paragraph(feature.Text, ContentWidth, Ui.SecondaryText));
            }

            content.Controls.Add(ReadyCard());

            var startup = new CheckBox
            {
                Text = "Avvia KeepMeOn all'accesso a Windows",
                AutoSize = true,
                Checked = StartupItem.IsEnabled,
                Margin = new Padding(0, 16, 0, 0),
            };
            startup.CheckedChanged += (sender, e) => StartupItem.SetEnabled(startup.Checked);
            content.Controls.Add(startup);

            content.Controls.Add(Buttons());
            Controls.Add(content);
            ResumeLayout(false);
            PerformLayout();
        }

        public event EventHandler SettingsRequested;

        private Control Header()
        {
            var header = new TableLayoutPanel
            {
                ColumnCount = 2,
                RowCount = 1,
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink,
                Margin = Padding.Empty,
            };

            var icon = new PictureBox
            {
                Size = new Size(64, 64),
                SizeMode = PictureBoxSizeMode.Zoom,
                Image = Ui.LoadIcon("AppIcon", new Size(64, 64)).ToBitmap(),
                Margin = new Padding(0, 0, 16, 0),
            };

            var titles = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                AutoSize = true,
                Margin = new Padding(0, 6, 0, 0),
            };
            titles.Controls.Add(new Label
            {
                Text = "Benvenuto in KeepMeOn",
                AutoSize = true,
                Font = Ui.Bold(Font, 16F),
                Margin = Padding.Empty,
            });
            titles.Controls.Add(Ui.Paragraph(
                "Resta disponibile su Teams anche quando ti allontani per un attimo.",
                ContentWidth - 80, Ui.SecondaryText, new Padding(0, 4, 0, 0)));

            header.Controls.Add(icon, 0, 0);
            header.Controls.Add(titles, 1, 0);
            return header;
        }

        private Control ReadyCard()
        {
            var card = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink,
                MinimumSize = new Size(ContentWidth, 0),
                BackColor = Ui.CardBackground,
                Padding = new Padding(14, 12, 14, 12),
                Margin = new Padding(0, 18, 0, 0),
            };
            card.Controls.Add(Ui.Heading("Pronta all'uso", Font, Padding.Empty));
            card.Controls.Add(Ui.Paragraph(
                "Su Windows non servono permessi: KeepMeOn lavora dall'icona con la tazzina vicino all'orologio. Se non la vedi, apri la freccia «Mostra icone nascoste» e trascinala sulla barra delle applicazioni.",
                ContentWidth - 28, Ui.SecondaryText, new Padding(0, 4, 0, 0)));
            return card;
        }

        private Control Buttons()
        {
            var row = new TableLayoutPanel
            {
                ColumnCount = 2,
                RowCount = 1,
                AutoSize = true,
                MinimumSize = new Size(ContentWidth, 0),
                Margin = new Padding(0, 18, 0, 0),
            };
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));

            var settings = new Button { Text = "Imposta orari…", AutoSize = true, Anchor = AnchorStyles.Left, Padding = new Padding(8, 2, 8, 2) };
            settings.Click += (sender, e) => SettingsRequested?.Invoke(this, EventArgs.Empty);

            var start = new Button { Text = "Inizia", AutoSize = true, Anchor = AnchorStyles.Right, Padding = new Padding(16, 2, 16, 2) };
            start.Click += (sender, e) => Close();
            AcceptButton = start;
            CancelButton = start;

            row.Controls.Add(settings, 0, 0);
            row.Controls.Add(start, 1, 0);
            return row;
        }
    }
}
