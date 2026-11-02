using System;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using KeepMeOn.Core;

namespace KeepMeOn
{
    /// <summary>Finestra «È disponibile KeepMeOn x.y.z»: novità, «Installa e riavvia», «Più tardi».</summary>
    internal sealed class UpdateForm : Form
    {
        private const int ContentWidth = 400;

        private readonly Updater updater;
        private readonly ReleaseAsset asset;
        private readonly ProgressBar progressBar;
        private readonly Label status;
        private readonly Button install;
        private readonly Button later;

        public UpdateForm(Updater updater, ReleaseInfo release, ReleaseAsset asset)
        {
            this.updater = updater;
            this.asset = asset;

            SuspendLayout();
            AutoScaleDimensions = new SizeF(96F, 96F);
            AutoScaleMode = AutoScaleMode.Dpi;
            Font = SystemFonts.MessageBoxFont;
            Text = L10n.T("Updating KeepMeOn", "Aggiornamento di KeepMeOn");
            Icon = Ui.AppIcon();
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            AutoSize = true;
            AutoSizeMode = AutoSizeMode.GrowAndShrink;
            TopMost = true;

            var content = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                AutoSize = true,
                AutoSizeMode = AutoSizeMode.GrowAndShrink,
                Padding = new Padding(24, 20, 24, 16),
            };

            content.Controls.Add(new Label
            {
                Text = L10n.T($"KeepMeOn {release.Version} is available", $"È disponibile KeepMeOn {release.Version}"),
                AutoSize = true,
                Font = Ui.Bold(Font, 12F),
                Margin = Padding.Empty,
            });
            content.Controls.Add(Ui.Paragraph(
                L10n.T($"You have version {updater.CurrentVersion}. The update downloads from GitHub and installs itself, then KeepMeOn reopens. Your settings are kept.",
                       $"Hai la versione {updater.CurrentVersion}. L'aggiornamento si scarica da GitHub e si installa da solo, poi KeepMeOn si riapre. Le impostazioni restano."),
                ContentWidth, Ui.SecondaryText, new Padding(0, 8, 0, 0)));

            var notes = new LinkLabel { Text = L10n.T("Read what's new", "Leggi le novità"), AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
            notes.LinkClicked += (sender, e) => Process.Start(release.PageUrl);
            content.Controls.Add(notes);

            progressBar = new ProgressBar { Width = ContentWidth, Height = 14, Visible = false, Margin = new Padding(0, 14, 0, 0) };
            status = Ui.Paragraph("", ContentWidth, Ui.SecondaryText, new Padding(0, 4, 0, 0));
            status.Visible = false;
            content.Controls.Add(progressBar);
            content.Controls.Add(status);

            var buttons = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.RightToLeft,
                AutoSize = true,
                MinimumSize = new Size(ContentWidth, 0),
                Margin = new Padding(0, 18, 0, 0),
            };
            install = new Button { Text = L10n.T("Install and restart", "Installa e riavvia"), AutoSize = true, Padding = new Padding(8, 2, 8, 2) };
            later = new Button { Text = L10n.T("Later", "Più tardi"), AutoSize = true, Padding = new Padding(8, 2, 8, 2), DialogResult = DialogResult.Cancel };
            install.Click += async (sender, e) => await InstallAsync();
            buttons.Controls.Add(install);
            buttons.Controls.Add(later);
            content.Controls.Add(buttons);
            AcceptButton = install;
            CancelButton = later;

            Controls.Add(content);
            ResumeLayout(false);
            PerformLayout();
        }

        private async System.Threading.Tasks.Task InstallAsync()
        {
            install.Enabled = later.Enabled = false;
            ControlBox = false;
            progressBar.Visible = status.Visible = true;
            status.Text = L10n.T("Downloading the update…", "Download dell'aggiornamento…");
            try
            {
                var progress = new Progress<int>(percent => progressBar.Value = percent);
                string installer = await Updater.DownloadAsync(asset, progress);
                status.Text = L10n.T("Installing: KeepMeOn will close and reopen on its own…", "Installazione: KeepMeOn si chiude e si riapre da sola…");
                Refresh();
                updater.LaunchInstaller(installer);
                DialogResult = DialogResult.OK;
                Close();
            }
            catch (Exception error)
            {
                Log.Write($"Aggiornamento: {error.Message}");
                Hide();
                Updater.ShowError(error);
                DialogResult = DialogResult.Abort;
                Close();
            }
        }
    }
}
