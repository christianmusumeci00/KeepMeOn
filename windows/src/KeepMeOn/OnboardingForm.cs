using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace KeepMeOn
{
    /// <summary>
    /// Configurazione guidata: al primo avvio e dal menu («Configurazione guidata…»).
    /// Su Windows non servono permessi, quindi i passi sono cinque.
    /// </summary>
    internal sealed class OnboardingForm : Form
    {
        private const int ContentWidth = 480;

        private static readonly string[] Titles = { "Benvenuto", "Quando", "Pausa pranzo", "Avvio e aggiornamenti", "Tutto pronto" };

        private readonly KeeperController controller;
        private readonly Updater updater;
        private readonly Panel host;
        private readonly StepDots dots;
        private readonly Label stepLabel;
        private readonly Button back;
        private readonly Button next;
        private int step;

        public OnboardingForm(KeeperController controller, Updater updater)
        {
            this.controller = controller;
            this.updater = updater;

            SuspendLayout();
            AutoScaleDimensions = new SizeF(96F, 96F);
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = SystemFonts.MessageBoxFont;
            Text = "Configurazione di KeepMeOn";
            Icon = Ui.AppIcon();
            BackColor = SystemColors.Window;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(560, 620);

            var root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 3, Margin = Padding.Empty };
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
            root.RowStyles.Add(new RowStyle(SizeType.AutoSize));

            // Puntini e nome del passo.
            var header = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                AutoSize = true,
                Anchor = AnchorStyles.None,
                Margin = new Padding(0, 14, 0, 4),
            };
            dots = new StepDots(Titles.Length) { Anchor = AnchorStyles.None, Margin = Padding.Empty };
            stepLabel = new Label { AutoSize = true, ForeColor = Ui.SecondaryText, Anchor = AnchorStyles.None, Margin = new Padding(0, 6, 0, 0) };
            header.Controls.Add(dots);
            header.Controls.Add(stepLabel);
            root.Controls.Add(header, 0, 0);

            host = new Panel { Dock = DockStyle.Fill, Padding = new Padding(36, 14, 36, 0), Margin = Padding.Empty };
            root.Controls.Add(host, 0, 1);

            // Pulsanti in basso, sotto una linea sottile.
            var footer = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                ColumnCount = 2,
                AutoSize = true,
                BackColor = SystemColors.Control,
                Padding = new Padding(16, 12, 16, 12),
                Margin = Padding.Empty,
            };
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
            back = new Button { Text = "Indietro", AutoSize = true, Anchor = AnchorStyles.Left, Padding = new Padding(10, 2, 10, 2) };
            next = new Button { Text = "Avanti", AutoSize = true, Anchor = AnchorStyles.Right, Padding = new Padding(14, 2, 14, 2) };
            back.Click += (sender, e) => GoTo(step - 1);
            next.Click += (sender, e) =>
            {
                if (step == Titles.Length - 1)
                {
                    Close();
                }
                else
                {
                    GoTo(step + 1);
                }
            };
            footer.Controls.Add(back, 0, 0);
            footer.Controls.Add(next, 1, 0);
            root.Controls.Add(footer, 0, 2);
            AcceptButton = next;

            Controls.Add(root);
            GoTo(0);
            ResumeLayout(false);
            PerformLayout();
        }

        /// <summary>Mostra un passo; le pagine si ricostruiscono, così il riepilogo è sempre aggiornato.</summary>
        internal void GoTo(int index)
        {
            step = Math.Max(0, Math.Min(index, Titles.Length - 1));
            host.SuspendLayout();
            foreach (Control old in host.Controls)
            {
                old.Dispose();
            }
            host.Controls.Clear();
            host.Controls.Add(BuildPage(step));
            host.ResumeLayout();

            dots.Current = step;
            stepLabel.Text = $"Passo {step + 1} di {Titles.Length} · {Titles[step]}";
            back.Visible = step > 0;
            next.Text = step == Titles.Length - 1 ? "Inizia" : "Avanti";
            next.Focus();
        }

        private Control BuildPage(int index)
        {
            var page = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink,
                Dock = DockStyle.Top,
                Margin = Padding.Empty,
            };
            switch (index)
            {
                case 0: BuildWelcome(page); break;
                case 1: BuildSchedule(page); break;
                case 2: BuildLunchBreak(page); break;
                case 3: BuildStartup(page); break;
                default: BuildDone(page); break;
            }
            return page;
        }

        // Passi.

        private void BuildWelcome(FlowLayoutPanel page)
        {
            var header = new TableLayoutPanel { ColumnCount = 2, AutoSize = true, Margin = Padding.Empty };
            header.Controls.Add(new PictureBox
            {
                Size = new Size(64, 64),
                SizeMode = PictureBoxSizeMode.Zoom,
                Image = Ui.LoadIcon("AppIcon", new Size(64, 64)).ToBitmap(),
                Margin = new Padding(0, 0, 16, 0),
            }, 0, 0);
            var titles = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoSize = true, Margin = new Padding(0, 6, 0, 0) };
            titles.Controls.Add(new Label { Text = "Benvenuto in KeepMeOn", AutoSize = true, Font = Ui.Bold(Font, 16F), Margin = Padding.Empty });
            titles.Controls.Add(Ui.Paragraph("Resta disponibile su Teams anche quando ti allontani per un attimo.",
                                             ContentWidth - 80, Ui.SecondaryText, new Padding(0, 4, 0, 0)));
            header.Controls.Add(titles, 1, 0);
            page.Controls.Add(header);

            page.Controls.Add(Ui.Paragraph(
                "Ti alzi per un caffè, rispondi al telefono o vai a ritirare una stampa: dopo pochi minuti senza mouse e tastiera Teams ti segna «Assente», anche se stai per tornare. KeepMeOn tiene il PC sveglio durante queste brevi pause, così resti verde e i colleghi sanno che sei raggiungibile.",
                ContentWidth, margin: new Padding(0, 16, 0, 2)));

            Feature(page, "Pause brevi, stato verde", "Interviene solo dopo 2 minuti in cui non usi il PC: mentre lavori non fa nulla.");
            Feature(page, "Non tocca niente", "Non muove il mouse, non preme tasti e non clicca: invia soltanto un segnale neutro al sistema. Non servono permessi.");
            Feature(page, "Si ferma da sola", "Con lo schermo bloccato, con il PC in sospensione o lo schermo spento e, se vuoi, fuori orario e in pausa pranzo.");
            Feature(page, "Via per più tempo?", "Blocca il PC con Windows+L: KeepMeOn si mette in pausa e Teams mostra correttamente che sei assente.");

            page.Controls.Add(Ui.Paragraph("In pochi passi scegli quando deve funzionare. Potrai cambiare tutto dal menu della tazzina.",
                                           ContentWidth, Ui.SecondaryText, new Padding(0, 16, 0, 0)));
        }

        private void BuildSchedule(FlowLayoutPanel page)
        {
            page.Controls.Add(Title("Quando deve funzionare?"));
            var always = new RadioButton { Text = "Sempre, quando il PC è acceso e sbloccato", AutoSize = true, Checked = !controller.WorkHoursOnly, Margin = new Padding(0, 14, 0, 0) };
            var workHoursOnly = new RadioButton { Text = "Solo in orario di lavoro", AutoSize = true, Checked = controller.WorkHoursOnly, Margin = new Padding(0, 6, 0, 0) };
            page.Controls.Add(always);
            page.Controls.Add(workHoursOnly);

            var editor = new WorkHoursEditor(controller, ContentWidth - 20) { Margin = new Padding(20, 12, 0, 0), Visible = controller.WorkHoursOnly };
            var alwaysNote = Ui.Paragraph("KeepMeOn interviene a qualsiasi ora del giorno; si ferma comunque con lo schermo bloccato e con il PC in sospensione.",
                                          ContentWidth, Ui.SecondaryText, new Padding(0, 12, 0, 0));
            alwaysNote.Visible = !controller.WorkHoursOnly;
            page.Controls.Add(editor);
            page.Controls.Add(alwaysNote);

            workHoursOnly.CheckedChanged += (sender, e) =>
            {
                controller.WorkHoursOnly = workHoursOnly.Checked;
                editor.Visible = workHoursOnly.Checked;
                alwaysNote.Visible = !workHoursOnly.Checked;
            };
        }

        private void BuildLunchBreak(FlowLayoutPanel page)
        {
            page.Controls.Add(Title("Pausa pranzo"));
            page.Controls.Add(Ui.Paragraph("A pranzo di solito ci si allontana a lungo: KeepMeOn può fermarsi, così Teams mostra che sei in pausa.",
                                           ContentWidth, Ui.SecondaryText, new Padding(0, 10, 0, 0)));
            var enabled = new CheckBox { Text = "Fermati durante la pausa pranzo", AutoSize = true, Checked = controller.LunchBreakEnabled, Margin = new Padding(0, 14, 0, 0) };
            var editor = new LunchBreakEditor(controller) { Margin = new Padding(20, 8, 0, 0), Editable = controller.LunchBreakEnabled };
            enabled.CheckedChanged += (sender, e) =>
            {
                controller.LunchBreakEnabled = enabled.Checked;
                editor.Editable = enabled.Checked;
            };
            page.Controls.Add(enabled);
            page.Controls.Add(editor);
            page.Controls.Add(Ui.Paragraph("La pausa vale tutti i giorni.", ContentWidth, Ui.SecondaryText, new Padding(0, 10, 0, 0)));
        }

        private void BuildStartup(FlowLayoutPanel page)
        {
            page.Controls.Add(Title("Avvio e aggiornamenti"));

            var startup = new CheckBox { Text = "Avvia KeepMeOn all'accesso a Windows", AutoSize = true, Checked = StartupItem.IsEnabled, Margin = new Padding(0, 16, 0, 0) };
            startup.CheckedChanged += (sender, e) => StartupItem.SetEnabled(startup.Checked);
            page.Controls.Add(startup);
            page.Controls.Add(Ui.Paragraph("Parte da sola quando accedi al PC, senza aprire finestre.",
                                           ContentWidth - 20, Ui.SecondaryText, new Padding(20, 2, 0, 0)));

            var updates = new CheckBox { Text = "Controlla aggiornamenti automaticamente", AutoSize = true, Checked = updater.AutomaticChecks, Margin = new Padding(0, 16, 0, 0) };
            updates.CheckedChanged += (sender, e) => updater.AutomaticChecks = updates.Checked;
            page.Controls.Add(updates);
            page.Controls.Add(Ui.Paragraph("Una volta al giorno KeepMeOn guarda su GitHub se c'è una nuova versione e ti chiede se installarla. Puoi farlo anche a mano dal menu, con «Controlla aggiornamenti…».",
                                           ContentWidth - 20, Ui.SecondaryText, new Padding(20, 2, 0, 0)));
        }

        private void BuildDone(FlowLayoutPanel page)
        {
            page.Controls.Add(Title("Tutto pronto"));
            page.Controls.Add(Ui.Paragraph("KeepMeOn lavora dall'icona vicino all'orologio. Ecco le tue scelte:",
                                           ContentWidth, Ui.SecondaryText, new Padding(0, 10, 0, 0)));

            var summary = new TableLayoutPanel
            {
                ColumnCount = 2,
                AutoSize = true,
                MinimumSize = new Size(ContentWidth, 0),
                BackColor = Ui.CardBackground,
                Padding = new Padding(14, 10, 14, 10),
                Margin = new Padding(0, 12, 0, 0),
            };
            SummaryRow(summary, "Quando", controller.WorkHoursOnly ? $"In orario di lavoro ({controller.WorkHours.Summary})" : "Sempre");
            SummaryRow(summary, "Pausa pranzo", controller.LunchBreakEnabled ? controller.LunchBreak.Summary : "No");
            SummaryRow(summary, "Avvio all'accesso", StartupItem.IsEnabled ? "Sì" : "No");
            SummaryRow(summary, "Aggiornamenti automatici", updater.AutomaticChecks ? "Sì" : "No");
            page.Controls.Add(summary);

            page.Controls.Add(Ui.Heading("L'icona vicino all'orologio", Font, new Padding(0, 16, 0, 0)));
            var legend = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0, 8, 0, 0) };
            Legend(legend, "TrayOff", "Spenta");
            Legend(legend, "TrayPaused", "In pausa");
            Legend(legend, "TrayCovering", "Ti tiene verde");
            page.Controls.Add(legend);

            page.Controls.Add(Ui.Paragraph("Se non la vedi, apri la freccia «Mostra icone nascoste» e trascinala sulla barra delle applicazioni. Puoi cambiare tutto quando vuoi dal menu della tazzina.",
                                           ContentWidth, Ui.SecondaryText, new Padding(0, 14, 0, 0)));
        }

        // Elementi.

        private Label Title(string text) => new Label { Text = text, AutoSize = true, Font = Ui.Bold(Font, 14F), Margin = Padding.Empty };

        private void Feature(FlowLayoutPanel page, string title, string text)
        {
            page.Controls.Add(Ui.Heading(title, Font, new Padding(0, 12, 0, 0)));
            page.Controls.Add(Ui.Paragraph(text, ContentWidth, Ui.SecondaryText));
        }

        private static void SummaryRow(TableLayoutPanel table, string label, string value)
        {
            table.Controls.Add(new Label { Text = label, AutoSize = true, Margin = new Padding(0, 3, 24, 3) });
            table.Controls.Add(new Label { Text = value, AutoSize = true, ForeColor = Ui.SecondaryText, MaximumSize = new Size(280, 0), Margin = new Padding(0, 3, 0, 3) });
        }

        private static void Legend(FlowLayoutPanel legend, string icon, string label)
        {
            legend.Controls.Add(new PictureBox
            {
                Size = new Size(24, 24),
                SizeMode = PictureBoxSizeMode.CenterImage,
                Image = Ui.LoadIcon(icon, new Size(24, 24)).ToBitmap(),
                Margin = new Padding(0, 0, 6, 0),
            });
            legend.Controls.Add(new Label { Text = label, AutoSize = true, ForeColor = Ui.SecondaryText, Margin = new Padding(0, 5, 22, 0) });
        }

        /// <summary>Puntini di avanzamento: pieni fino al passo corrente, quello corrente allungato.</summary>
        private sealed class StepDots : Control
        {
            private const int Dot = 8;
            private const int Gap = 6;
            private const int Wide = 22;
            private readonly int count;
            private int current;

            public StepDots(int count)
            {
                this.count = count;
                DoubleBuffered = true;
                Size = new Size(count * Dot + (count - 1) * Gap + (Wide - Dot), Dot);
            }

            public int Current
            {
                set
                {
                    current = value;
                    Invalidate();
                }
            }

            protected override void OnPaint(PaintEventArgs e)
            {
                e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
                float scale = DeviceDpi / 96F;
                float x = 0;
                for (int i = 0; i < count; i++)
                {
                    float width = (i == current ? Wide : Dot) * scale;
                    float height = Dot * scale;
                    using (var brush = new SolidBrush(i <= current ? Color.FromArgb(0, 103, 192) : Color.FromArgb(205, 205, 205)))
                    using (var path = new GraphicsPath())
                    {
                        path.AddArc(x, 0, height, height, 90, 180);
                        path.AddArc(x + width - height, 0, height, height, 270, 180);
                        path.CloseFigure();
                        e.Graphics.FillPath(brush, path);
                    }
                    x += width + Gap * scale;
                }
            }
        }
    }
}
