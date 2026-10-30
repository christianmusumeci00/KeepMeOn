using System.Drawing;
using System.Windows.Forms;

namespace KeepMeOn
{
    /// <summary>Finestra degli orari: fascia di lavoro (inizio, fine, giorni) e pausa pranzo. Le modifiche valgono subito.</summary>
    internal sealed class SettingsForm : Form
    {
        private const int NoteWidth = 400;

        public SettingsForm(KeeperController controller)
        {
            SuspendLayout();
            AutoScaleDimensions = new SizeF(96F, 96F);
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = SystemFonts.MessageBoxFont;
            Text = "KeepMeOn – Orari";
            Icon = Ui.AppIcon();
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            AutoSize = true;
            AutoSizeMode = AutoSizeMode.GrowAndShrink;

            var content = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink,
                Padding = new Padding(20, 16, 20, 16),
            };

            var workHoursOnly = new CheckBox { Text = "Solo in orario di lavoro", AutoSize = true, Checked = controller.WorkHoursOnly };
            var workHours = new WorkHoursEditor(controller, NoteWidth) { Margin = new Padding(0, 4, 0, 0) };
            content.Controls.Add(workHoursOnly);
            content.Controls.Add(workHours);

            content.Controls.Add(new Label { BorderStyle = BorderStyle.Fixed3D, Height = 2, Width = NoteWidth + 20, Margin = new Padding(0, 14, 0, 14) });

            var lunchEnabled = new CheckBox { Text = "Pausa pranzo", AutoSize = true, Checked = controller.LunchBreakEnabled };
            var lunchBreak = new LunchBreakEditor(controller) { Margin = new Padding(0, 4, 0, 0) };
            content.Controls.Add(lunchEnabled);
            content.Controls.Add(lunchBreak);
            content.Controls.Add(Ui.Paragraph("Durante la pausa pranzo KeepMeOn non interviene, tutti i giorni.",
                                              NoteWidth, Ui.SecondaryText, new Padding(0, 6, 0, 0)));

            var close = new Button { Text = "Chiudi", AutoSize = true, Padding = new Padding(12, 2, 12, 2) };
            close.Click += (sender, e) => Close();
            var closeRow = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.RightToLeft,
                AutoSize = true,
                MinimumSize = new Size(NoteWidth + 20, 0),
                Margin = new Padding(0, 16, 0, 0),
            };
            closeRow.Controls.Add(close);
            content.Controls.Add(closeRow);
            AcceptButton = close;
            CancelButton = close;

            Controls.Add(content);

            // Collegamenti dopo aver impostato i valori iniziali, così non scattano all'apertura.
            workHoursOnly.CheckedChanged += (sender, e) =>
            {
                controller.WorkHoursOnly = workHoursOnly.Checked;
                workHours.Editable = workHoursOnly.Checked;
            };
            lunchEnabled.CheckedChanged += (sender, e) =>
            {
                controller.LunchBreakEnabled = lunchEnabled.Checked;
                lunchBreak.Editable = lunchEnabled.Checked;
            };
            workHours.Editable = workHoursOnly.Checked;
            lunchBreak.Editable = lunchEnabled.Checked;

            ResumeLayout(false);
            PerformLayout();
        }
    }
}
