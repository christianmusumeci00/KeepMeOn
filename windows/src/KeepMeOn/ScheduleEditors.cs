using System;
using System.Windows.Forms;
using KeepMeOn.Core;

namespace KeepMeOn
{
    /// <summary>
    /// Ora di inizio, ora di fine e giorni, con la nota sotto: nella finestra degli orari e nella
    /// configurazione guidata. Le modifiche valgono subito.
    /// </summary>
    internal sealed class WorkHoursEditor : TableLayoutPanel
    {
        private readonly KeeperController controller;
        private readonly DateTimePicker start;
        private readonly DateTimePicker end;
        private readonly FlowLayoutPanel days;
        private readonly Label note;

        public WorkHoursEditor(KeeperController controller, int noteWidth)
        {
            this.controller = controller;
            ColumnCount = 2;
            AutoSize = true;
            AutoSizeMode = AutoSizeMode.GrowAndShrink;
            Margin = Padding.Empty;

            start = Editors.TimePicker(controller.WorkHours.StartMinute);
            end = Editors.TimePicker(controller.WorkHours.EndMinute);
            days = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0, 3, 0, 3) };
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
                days.Controls.Add(box);
            }
            note = Ui.Paragraph("", noteWidth, Ui.SecondaryText, new Padding(0, 6, 0, 0));

            Editors.AddRow(this, "Inizio:", start);
            Editors.AddRow(this, "Fine:", end);
            Editors.AddRow(this, "Giorni:", days);
            Editors.AddRow(this, null, note);

            start.ValueChanged += (sender, e) => { controller.WorkHours = controller.WorkHours.WithStart(Editors.MinuteOf(start)); UpdateNote(); };
            end.ValueChanged += (sender, e) => { controller.WorkHours = controller.WorkHours.WithEnd(Editors.MinuteOf(end)); UpdateNote(); };
            UpdateNote();
        }

        public bool Editable
        {
            set => start.Enabled = end.Enabled = days.Enabled = value;
        }

        private void UpdateNote()
        {
            var hours = controller.WorkHours;
            string text = "Fuori fascia KeepMeOn resta acceso ma non interviene.";
            if (hours.StartMinute == hours.EndMinute)
            {
                text += " Inizio e fine coincidono: la fascia copre l'intera giornata.";
            }
            else if (hours.StartMinute > hours.EndMinute)
            {
                text += " La fascia termina il giorno dopo, come un turno di notte.";
            }
            note.Text = text;
        }
    }

    /// <summary>Inizio e fine della pausa pranzo.</summary>
    internal sealed class LunchBreakEditor : TableLayoutPanel
    {
        private readonly DateTimePicker start;
        private readonly DateTimePicker end;

        public LunchBreakEditor(KeeperController controller)
        {
            ColumnCount = 2;
            AutoSize = true;
            AutoSizeMode = AutoSizeMode.GrowAndShrink;
            Margin = Padding.Empty;

            start = Editors.TimePicker(controller.LunchBreak.StartMinute);
            end = Editors.TimePicker(controller.LunchBreak.EndMinute);
            Editors.AddRow(this, "Dalle:", start);
            Editors.AddRow(this, "Alle:", end);

            start.ValueChanged += (sender, e) => controller.LunchBreak = controller.LunchBreak.WithStart(Editors.MinuteOf(start));
            end.ValueChanged += (sender, e) => controller.LunchBreak = controller.LunchBreak.WithEnd(Editors.MinuteOf(end));
        }

        public bool Editable
        {
            set => start.Enabled = end.Enabled = value;
        }
    }

    internal static class Editors
    {
        /// <summary>Larghezza della colonna delle etichette, uguale in tutti i blocchi così i campi restano allineati.</summary>
        private const int LabelWidth = 56;

        public static void AddRow(TableLayoutPanel grid, string label, Control control)
        {
            if (label == null)
            {
                grid.Controls.Add(control);
                grid.SetColumnSpan(control, 2);
                return;
            }
            grid.Controls.Add(new Label
            {
                Text = label,
                AutoSize = false,
                Width = LabelWidth,
                Height = 24,
                TextAlign = System.Drawing.ContentAlignment.MiddleLeft,
                Margin = new Padding(0, 3, 4, 0),
            });
            grid.Controls.Add(control);
        }

        public static DateTimePicker TimePicker(int minute) => new DateTimePicker
        {
            Format = DateTimePickerFormat.Custom,
            CustomFormat = "HH:mm",
            ShowUpDown = true,
            Width = 80,
            Value = DateTime.Today.AddMinutes(minute),
            Margin = new Padding(0, 3, 0, 3),
        };

        public static int MinuteOf(DateTimePicker picker) => picker.Value.Hour * 60 + picker.Value.Minute;
    }
}
