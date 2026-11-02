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

        private const int StepCount = 5;

        private readonly KeeperController controller;
        private readonly Updater updater;
        private readonly Panel host;
        private readonly StepDots dots;
        private readonly Label stepLabel;
        private readonly FlowLayoutPanel leftSlot;
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
            dots = new StepDots(StepCount) { Anchor = AnchorStyles.None, Margin = Padding.Empty };
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
            // A sinistra «Indietro», oppure la scelta della lingua nel primo passo.
            leftSlot = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Anchor = AnchorStyles.Left, Margin = Padding.Empty };
            back = new Button { AutoSize = true, Padding = new Padding(10, 2, 10, 2), Margin = Padding.Empty };
            next = new Button { AutoSize = true, Anchor = AnchorStyles.Right, Padding = new Padding(14, 2, 14, 2) };
            back.Click += (sender, e) => GoTo(step - 1);
            next.Click += (sender, e) =>
            {
                if (step == StepCount - 1)
                {
                    Close();
                }
                else
                {
                    GoTo(step + 1);
                }
            };
            footer.Controls.Add(leftSlot, 0, 0);
            footer.Controls.Add(next, 1, 0);
            root.Controls.Add(footer, 0, 2);
            AcceptButton = next;

            Controls.Add(root);
            GoTo(0);
            L10n.Changed += OnLanguageChanged;
            FormClosed += (sender, e) => L10n.Changed -= OnLanguageChanged;
            ResumeLayout(false);
            PerformLayout();
        }

        private static string Title(int index)
        {
            switch (index)
            {
                case 0: return L10n.T("Welcome", "Benvenuto");
                case 1: return L10n.T("When", "Quando");
                case 2: return L10n.T("Lunch Break", "Pausa pranzo");
                case 3: return L10n.T("Startup & Updates", "Avvio e aggiornamenti");
                default: return L10n.T("All Set", "Tutto pronto");
            }
        }

        private void OnLanguageChanged(object sender, EventArgs e) => GoTo(step);

        /// <summary>Mostra un passo; le pagine si ricostruiscono, così il riepilogo è sempre aggiornato.</summary>
        internal void GoTo(int index)
        {
            step = Math.Max(0, Math.Min(index, StepCount - 1));
            Text = L10n.T("KeepMeOn Setup", "Configurazione di KeepMeOn");
            host.SuspendLayout();
            foreach (Control old in host.Controls)
            {
                old.Dispose();
            }
            host.Controls.Clear();
            host.Controls.Add(BuildPage(step));
            host.ResumeLayout();

            leftSlot.SuspendLayout();
            leftSlot.Controls.Remove(back);
            while (leftSlot.Controls.Count > 0)
            {
                leftSlot.Controls[0].Dispose();
            }
            leftSlot.Controls.Add(step == 0 ? Ui.LanguagePicker(Padding.Empty) : back);
            leftSlot.ResumeLayout();

            dots.Current = step;
            stepLabel.Text = L10n.T($"Step {step + 1} of {StepCount}", $"Passo {step + 1} di {StepCount}") + $" · {Title(step)}";
            back.Text = L10n.T("Back", "Indietro");
            next.Text = step == StepCount - 1 ? L10n.T("Get Started", "Inizia") : L10n.T("Next", "Avanti");
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
            titles.Controls.Add(new Label { Text = L10n.T("Welcome to KeepMeOn", "Benvenuto in KeepMeOn"), AutoSize = true, Font = Ui.Bold(Font, 16F), Margin = Padding.Empty });
            titles.Controls.Add(Ui.Paragraph(L10n.T("Stay available on Teams even when you step away for a moment.",
                                                    "Resta disponibile su Teams anche quando ti allontani per un attimo."),
                                             ContentWidth - 80, Ui.SecondaryText, new Padding(0, 4, 0, 0)));
            header.Controls.Add(titles, 1, 0);
            page.Controls.Add(header);

            page.Controls.Add(Ui.Paragraph(
                L10n.T("You get up for a coffee, answer the phone or grab a printout: after a few minutes without mouse or keyboard, Teams marks you as “Away”, even though you're about to come back. KeepMeOn keeps your PC awake during these short breaks, so you stay green and your colleagues know they can reach you.",
                       "Ti alzi per un caffè, rispondi al telefono o vai a ritirare una stampa: dopo pochi minuti senza mouse e tastiera Teams ti segna «Assente», anche se stai per tornare. KeepMeOn tiene il PC sveglio durante queste brevi pause, così resti verde e i colleghi sanno che sei raggiungibile."),
                ContentWidth, margin: new Padding(0, 16, 0, 2)));

            Feature(page, L10n.T("Short breaks, green status", "Pause brevi, stato verde"),
                    L10n.T("It only steps in after 2 minutes without using your PC: while you work, it does nothing.",
                           "Interviene solo dopo 2 minuti in cui non usi il PC: mentre lavori non fa nulla."));
            Feature(page, L10n.T("Hands off", "Non tocca niente"),
                    L10n.T("It doesn't move the mouse, press keys or click: it only sends a neutral signal to the system. No permissions needed.",
                           "Non muove il mouse, non preme tasti e non clicca: invia soltanto un segnale neutro al sistema. Non servono permessi."));
            Feature(page, L10n.T("Stops on its own", "Si ferma da sola"),
                    L10n.T("When the screen is locked, when the PC is asleep or the display is off and, if you like, outside work hours and at lunch.",
                           "Con lo schermo bloccato, con il PC in sospensione o lo schermo spento e, se vuoi, fuori orario e in pausa pranzo."));
            Feature(page, L10n.T("Away for longer?", "Via per più tempo?"),
                    L10n.T("Lock your PC with Windows+L: KeepMeOn pauses and Teams correctly shows that you're away.",
                           "Blocca il PC con Windows+L: KeepMeOn si mette in pausa e Teams mostra correttamente che sei assente."));

            page.Controls.Add(Ui.Paragraph(L10n.T("In a few steps, choose when it should run. You can change everything later from the cup menu.",
                                                  "In pochi passi scegli quando deve funzionare. Potrai cambiare tutto dal menu della tazzina."),
                                           ContentWidth, Ui.SecondaryText, new Padding(0, 16, 0, 0)));
        }

        private void BuildSchedule(FlowLayoutPanel page)
        {
            page.Controls.Add(PageTitle(L10n.T("When should it run?", "Quando deve funzionare?")));
            var always = new RadioButton { Text = L10n.T("Always, when the PC is on and unlocked", "Sempre, quando il PC è acceso e sbloccato"), AutoSize = true, Checked = !controller.WorkHoursOnly, Margin = new Padding(0, 14, 0, 0) };
            var workHoursOnly = new RadioButton { Text = L10n.T("Only during work hours", "Solo in orario di lavoro"), AutoSize = true, Checked = controller.WorkHoursOnly, Margin = new Padding(0, 6, 0, 0) };
            page.Controls.Add(always);
            page.Controls.Add(workHoursOnly);

            var editor = new WorkHoursEditor(controller, ContentWidth - 20) { Margin = new Padding(20, 12, 0, 0), Visible = controller.WorkHoursOnly };
            var alwaysNote = Ui.Paragraph(L10n.T("KeepMeOn works at any time of day; it still stops when the screen is locked or the PC is asleep.",
                                                 "KeepMeOn interviene a qualsiasi ora del giorno; si ferma comunque con lo schermo bloccato e con il PC in sospensione."),
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
            page.Controls.Add(PageTitle(L10n.T("Lunch Break", "Pausa pranzo")));
            page.Controls.Add(Ui.Paragraph(L10n.T("At lunch you're usually away for a while: KeepMeOn can stop, so Teams shows that you're on a break.",
                                                  "A pranzo di solito ci si allontana a lungo: KeepMeOn può fermarsi, così Teams mostra che sei in pausa."),
                                           ContentWidth, Ui.SecondaryText, new Padding(0, 10, 0, 0)));
            var enabled = new CheckBox { Text = L10n.T("Pause during the lunch break", "Fermati durante la pausa pranzo"), AutoSize = true, Checked = controller.LunchBreakEnabled, Margin = new Padding(0, 14, 0, 0) };
            var editor = new LunchBreakEditor(controller) { Margin = new Padding(20, 8, 0, 0), Editable = controller.LunchBreakEnabled };
            enabled.CheckedChanged += (sender, e) =>
            {
                controller.LunchBreakEnabled = enabled.Checked;
                editor.Editable = enabled.Checked;
            };
            page.Controls.Add(enabled);
            page.Controls.Add(editor);
            page.Controls.Add(Ui.Paragraph(L10n.T("The break applies every day.", "La pausa vale tutti i giorni."), ContentWidth, Ui.SecondaryText, new Padding(0, 10, 0, 0)));
        }

        private void BuildStartup(FlowLayoutPanel page)
        {
            page.Controls.Add(PageTitle(L10n.T("Startup & Updates", "Avvio e aggiornamenti")));

            var startup = new CheckBox { Text = L10n.T("Start KeepMeOn when you sign in to Windows", "Avvia KeepMeOn all'accesso a Windows"), AutoSize = true, Checked = StartupItem.IsEnabled, Margin = new Padding(0, 16, 0, 0) };
            startup.CheckedChanged += (sender, e) => StartupItem.SetEnabled(startup.Checked);
            page.Controls.Add(startup);
            page.Controls.Add(Ui.Paragraph(L10n.T("It starts on its own when you sign in to your PC, without opening any windows.",
                                                  "Parte da sola quando accedi al PC, senza aprire finestre."),
                                           ContentWidth - 20, Ui.SecondaryText, new Padding(20, 2, 0, 0)));

            var updates = new CheckBox { Text = L10n.T("Check for updates automatically", "Controlla aggiornamenti automaticamente"), AutoSize = true, Checked = updater.AutomaticChecks, Margin = new Padding(0, 16, 0, 0) };
            updates.CheckedChanged += (sender, e) => updater.AutomaticChecks = updates.Checked;
            page.Controls.Add(updates);
            page.Controls.Add(Ui.Paragraph(L10n.T("Once a day KeepMeOn checks GitHub for a new version and asks whether to install it. You can also do it yourself from the menu, with “Check for Updates…”.",
                                                  "Una volta al giorno KeepMeOn guarda su GitHub se c'è una nuova versione e ti chiede se installarla. Puoi farlo anche a mano dal menu, con «Controlla aggiornamenti…»."),
                                           ContentWidth - 20, Ui.SecondaryText, new Padding(20, 2, 0, 0)));
        }

        private void BuildDone(FlowLayoutPanel page)
        {
            page.Controls.Add(PageTitle(L10n.T("All Set", "Tutto pronto")));
            page.Controls.Add(Ui.Paragraph(L10n.T("KeepMeOn works from the icon near the clock. Here are your choices:",
                                                  "KeepMeOn lavora dall'icona vicino all'orologio. Ecco le tue scelte:"),
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
            SummaryRow(summary, L10n.T("When", "Quando"), controller.WorkHoursOnly
                ? L10n.T("During work hours", "In orario di lavoro") + $" ({controller.WorkHours.Summary(L10n.Current)})"
                : L10n.T("Always", "Sempre"));
            SummaryRow(summary, L10n.T("Lunch break", "Pausa pranzo"), controller.LunchBreakEnabled ? controller.LunchBreak.Summary : L10n.T("No", "No"));
            SummaryRow(summary, L10n.T("Start with Windows", "Avvio all'accesso"), YesNo(StartupItem.IsEnabled));
            SummaryRow(summary, L10n.T("Automatic updates", "Aggiornamenti automatici"), YesNo(updater.AutomaticChecks));
            page.Controls.Add(summary);

            page.Controls.Add(Ui.Heading(L10n.T("The icon near the clock", "L'icona vicino all'orologio"), Font, new Padding(0, 16, 0, 0)));
            var legend = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0, 8, 0, 0) };
            Legend(legend, "TrayOff", L10n.T("Off", "Spenta"));
            Legend(legend, "TrayPaused", L10n.T("Paused", "In pausa"));
            Legend(legend, "TrayCovering", L10n.T("Keeping you green", "Ti tiene verde"));
            page.Controls.Add(legend);

            page.Controls.Add(Ui.Paragraph(L10n.T("If you don't see it, open the “Show hidden icons” arrow and drag it onto the taskbar. You can change everything anytime from the cup menu.",
                                                  "Se non la vedi, apri la freccia «Mostra icone nascoste» e trascinala sulla barra delle applicazioni. Puoi cambiare tutto quando vuoi dal menu della tazzina."),
                                           ContentWidth, Ui.SecondaryText, new Padding(0, 14, 0, 0)));
        }

        // Elementi.

        private static string YesNo(bool value) => value ? L10n.T("Yes", "Sì") : L10n.T("No", "No");

        private Label PageTitle(string text) => new Label { Text = text, AutoSize = true, Font = Ui.Bold(Font, 14F), Margin = Padding.Empty };

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
