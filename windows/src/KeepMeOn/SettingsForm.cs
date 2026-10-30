using System;
using System.Drawing;
using System.Windows.Forms;
using KeepMeOn.Core;

namespace KeepMeOn
{
    /// <summary>Finestra degli orari: fascia di lavoro (inizio, fine, giorni) e pausa pranzo. Le modifiche valgono subito.</summary>
    internal sealed class SettingsForm : Form
    {
        private const int NoteWidth = 400;

        private readonly KeeperController controller;
        private readonly Label workHoursNote;

        public SettingsForm(KeeperController controller)
        {
            this.controller = controller;

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

            var grid = new TableLayoutPanel
            {
                ColumnCount = 2,
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink,
                Padding = new Padding(20, 16, 20, 16),
            };

            // Orario di lavoro.
            var workHoursOnly = new CheckBox { Text = "Solo in orario di lavoro", AutoSize = true, Checked = controller.WorkHoursOnly };
            var start = TimePicker(controller.WorkHours.StartMinute);
            var end = TimePicker(controller.WorkHours.EndMinute);
            var days = DayCheckBoxes();
            workHoursNote = Ui.Paragraph("", NoteWidth, Ui.SecondaryText, new Padding(0, 6, 0, 0));

            AddRow(grid, null, workHoursOnly);
            AddRow(grid, "Inizio:", start);
            AddRow(grid, "Fine:", end);
            AddRow(grid, "Giorni:", days);
            AddRow(grid, null, workHoursNote);

            var separator = new Label { BorderStyle = BorderStyle.Fixed3D, Height = 2, Dock = DockStyle.Fill, Margin = new Padding(0, 14, 0, 14) };
            grid.Controls.Add(separator);
            grid.SetColumnSpan(separator, 2);

            // Pausa pranzo.
            var lunchEnabled = new CheckBox { Text = "Pausa pranzo", AutoSize = true, Checked = controller.LunchBreakEnabled };
            var lunchStart = TimePicker(controller.LunchBreak.StartMinute);
            var lunchEnd = TimePicker(controller.LunchBreak.EndMinute);
            AddRow(grid, null, lunchEnabled);
            AddRow(grid, "Dalle:", lunchStart);
            AddRow(grid, "Alle:", lunchEnd);
            AddRow(grid, null, Ui.Paragraph("Durante la pausa pranzo KeepMeOn non interviene, tutti i giorni.", NoteWidth, Ui.SecondaryText, new Padding(0, 6, 0, 0)));

            var close = new Button { Text = "Chiudi", AutoSize = true, Anchor = AnchorStyles.Right, Padding = new Padding(12, 2, 12, 2), Margin = new Padding(0, 16, 0, 0) };
            close.Click += (sender, e) => Close();
            grid.Controls.Add(close);
            grid.SetColumnSpan(close, 2);
            AcceptButton = close;
            CancelButton = close;

            Controls.Add(grid);

            // Collegamenti dopo aver impostato i valori iniziali, così non scattano all'apertura.
            void UpdateEnabled()
            {
                start.Enabled = end.Enabled = days.Enabled = workHoursOnly.Checked;
                lunchStart.Enabled = lunchEnd.Enabled = lunchEnabled.Checked;
                UpdateWorkHoursNote();
            }
            workHoursOnly.CheckedChanged += (sender, e) => { controller.WorkHoursOnly = workHoursOnly.Checked; UpdateEnabled(); };
            start.ValueChanged += (sender, e) => { controller.WorkHours = controller.WorkHours.WithStart(MinuteOf(start)); UpdateWorkHoursNote(); };
            end.ValueChanged += (sender, e) => { controller.WorkHours = controller.WorkHours.WithEnd(MinuteOf(end)); UpdateWorkHoursNote(); };
            lunchEnabled.CheckedChanged += (sender, e) => { controller.LunchBreakEnabled = lunchEnabled.Checked; UpdateEnabled(); };
            lunchStart.ValueChanged += (sender, e) => controller.LunchBreak = controller.LunchBreak.WithStart(MinuteOf(lunchStart));
            lunchEnd.ValueChanged += (sender, e) => controller.LunchBreak = controller.LunchBreak.WithEnd(MinuteOf(lunchEnd));
            UpdateEnabled();

            ResumeLayout(false);
            PerformLayout();
        }

        private void UpdateWorkHoursNote()
        {
            var hours = controller.WorkHours;
            string note = "Fuori fascia KeepMeOn resta acceso ma non interviene.";
            if (hours.StartMinute == hours.EndMinute)
            {
                note += " Inizio e fine coincidono: la fascia copre l'intera giornata.";
            }
            else if (hours.StartMinute > hours.EndMinute)
            {
                note += " La fascia termina il giorno dopo, come un turno di notte.";
            }
            workHoursNote.Text = note;
        }

        private Control DayCheckBoxes()
        {
            var row = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0, 3, 0, 3) };
            foreach (int day in WorkHours.MondayFirst)
            {
                string name = WorkHours.ShortName(day);
                var box = new CheckBox
                {
                    Text = char.ToUpperInvariant(name[0]) + name.Substring(1),
                    AutoSize = true,
                    Checked = controller.WorkHours.IncludesDay(day),
                    Margin = new Padding(0, 0, 8, 0),
                };
                box.CheckedChanged += (sender, e) => controller.WorkHours = controller.WorkHours.WithDay(day, box.Checked);
                row.Controls.Add(box);
            }
            return row;
        }

        private static void AddRow(TableLayoutPanel grid, string label, Control control)
        {
            if (label == null)
            {
                grid.Controls.Add(control);
                grid.SetColumnSpan(control, 2);
                return;
            }
            grid.Controls.Add(new Label { Text = label, AutoSize = true, Anchor = AnchorStyles.Right, Margin = new Padding(0, 6, 8, 0) });
            grid.Controls.Add(control);
        }

        private static DateTimePicker TimePicker(int minute) => new DateTimePicker
        {
            Format = DateTimePickerFormat.Custom,
            CustomFormat = "HH:mm",
            ShowUpDown = true,
            Width = 80,
            Value = DateTime.Today.AddMinutes(minute),
            Margin = new Padding(0, 3, 0, 3),
        };

        private static int MinuteOf(DateTimePicker picker) => picker.Value.Hour * 60 + picker.Value.Minute;
    }
}
