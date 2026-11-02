using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Reflection;
using System.Threading.Tasks;
using System.Windows.Forms;
using KeepMeOn.Core;
using Timer = System.Windows.Forms.Timer;

namespace KeepMeOn
{
    /// <summary>
    /// Aggiornamenti dalla pagina Release di GitHub.
    /// - Controllo a mano dal menu, oppure automatico: al massimo una volta al giorno.
    /// - Se c'è una versione nuova chiede se installarla, scarica l'installer e lo avvia in modalità
    ///   silenziosa: l'installer chiude KeepMeOn, la aggiorna e la riapre. Le impostazioni restano.
    /// </summary>
    internal sealed class Updater : IDisposable
    {
        /// <summary>Nome del file della release per Windows.</summary>
        public const string AssetName = "KeepMeOn-Setup.exe";

        private readonly SettingsStore settings;
        private readonly Timer hourly = new Timer { Interval = 60 * 60 * 1000 };
        private readonly Timer firstCheck = new Timer { Interval = 30 * 1000 };

        public Updater(SettingsStore settings)
        {
            this.settings = settings;
            CurrentVersion = AppVersion.FromSystemVersion(Assembly.GetExecutingAssembly().GetName().Version);
            hourly.Tick += async (sender, e) => await AutomaticCheckAsync();
            firstCheck.Tick += async (sender, e) =>
            {
                firstCheck.Stop();
                await AutomaticCheckAsync();
            };
        }

        /// <summary>Stato cambiato (controllo in corso, impostazione): il menu si aggiorna.</summary>
        public event EventHandler Changed;

        /// <summary>L'installer è partito: l'app deve chiudersi.</summary>
        public event EventHandler InstallerStarted;

        public AppVersion CurrentVersion { get; }

        public bool IsBusy { get; private set; }

        public bool AutomaticChecks
        {
            get => settings.AutomaticUpdateChecks;
            set
            {
                settings.AutomaticUpdateChecks = value;
                Start();
                Changed?.Invoke(this, EventArgs.Empty);
            }
        }

        /// <summary>Avvia i controlli automatici, se attivi: il primo poco dopo l'avvio, poi ogni ora si guarda se è passato un giorno.</summary>
        public void Start()
        {
            hourly.Stop();
            firstCheck.Stop();
            if (AutomaticChecks)
            {
                hourly.Start();
                firstCheck.Start();
            }
        }

        private async Task AutomaticCheckAsync()
        {
            if (AutomaticChecks && !IsBusy && UpdatePolicy.IsCheckDue(settings.LastUpdateCheck, DateTime.Now))
            {
                await CheckAsync(userInitiated: false);
            }
        }

        public async Task CheckAsync(bool userInitiated)
        {
            if (IsBusy)
            {
                return;
            }
            SetBusy(true);
            try
            {
                var release = await FetchLatestReleaseAsync(settings.UpdateFeedUrl);
                settings.LastUpdateCheck = DateTime.Now;
                var asset = UpdatePolicy.AvailableUpdate(release, CurrentVersion, AssetName);
                if (asset == null)
                {
                    Log.Write($"Nessun aggiornamento (in uso {CurrentVersion}, ultima {release.TagName})");
                    if (userInitiated)
                    {
                        MessageBox.Show(L10n.T($"You have the latest version, {CurrentVersion}.", $"Hai l'ultima versione disponibile, la {CurrentVersion}."),
                                        L10n.T("KeepMeOn is up to date", "KeepMeOn è aggiornata"),
                                        MessageBoxButtons.OK, MessageBoxIcon.Information);
                    }
                    return;
                }

                Log.Write($"Disponibile la versione {release.Version}");
                using (var form = new UpdateForm(this, release, asset))
                {
                    form.ShowDialog();
                }
            }
            catch (Exception error)
            {
                Log.Write($"Aggiornamento: {error.Message}");
                if (userInitiated)
                {
                    ShowError(error);
                }
            }
            finally
            {
                SetBusy(false);
            }
        }

        /// <summary>
        /// Ultima release pubblicata. Per le prove l'indirizzo può essere un file locale; il token serve
        /// solo alle verifiche automatiche su GitHub, dove le richieste anonime hanno un limite orario.
        /// </summary>
        internal static async Task<ReleaseInfo> FetchLatestReleaseAsync(string feedUrl = null, string token = null)
        {
            string url = string.IsNullOrEmpty(feedUrl) ? UpdatePolicy.LatestReleaseUrl : feedUrl;
            if (url.StartsWith("file:", StringComparison.OrdinalIgnoreCase))
            {
                return ReleaseInfo.Parse(File.ReadAllText(new Uri(url).LocalPath));
            }
            using (var client = NewClient())
            {
                client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
                if (!string.IsNullOrEmpty(token))
                {
                    client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
                }
                return ReleaseInfo.Parse(await client.GetStringAsync(url));
            }
        }

        /// <summary>Scarica l'installer nella cartella temporanea e restituisce il percorso del file.</summary>
        internal static async Task<string> DownloadAsync(ReleaseAsset asset, IProgress<int> progress)
        {
            string path = Path.Combine(Path.GetTempPath(), $"KeepMeOn-Setup-{Guid.NewGuid():N}.exe");
            var source = new Uri(asset.DownloadUrl);
            if (source.IsFile)
            {
                File.Copy(source.LocalPath, path, true);
                progress?.Report(100);
                return path;
            }

            using (var client = NewClient())
            using (var response = await client.GetAsync(source, HttpCompletionOption.ResponseHeadersRead))
            {
                response.EnsureSuccessStatusCode();
                long total = response.Content.Headers.ContentLength ?? asset.Size;
                using (var input = await response.Content.ReadAsStreamAsync())
                using (var output = File.Create(path))
                {
                    var buffer = new byte[81920];
                    long received = 0;
                    int read;
                    while ((read = await input.ReadAsync(buffer, 0, buffer.Length)) > 0)
                    {
                        await output.WriteAsync(buffer, 0, read);
                        received += read;
                        if (total > 0)
                        {
                            progress?.Report((int)Math.Min(100, received * 100 / total));
                        }
                    }
                }
            }
            return path;
        }

        /// <summary>
        /// Parametri dell'installer per un aggiornamento: senza finestre, e con le stesse scelte
        /// di oggi su avvio all'accesso e lingua, così l'aggiornamento non le cambia.
        /// </summary>
        internal static string InstallerArguments(bool startupEnabled, Language language) =>
            "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /MERGETASKS=\"" + (startupEnabled ? "startup" : "!startup") + "\"" +
            " /LANG=" + language.Code();

        /// <summary>Avvia l'installer scaricato e chiede all'app di chiudersi.</summary>
        public void LaunchInstaller(string path)
        {
            Log.Write("Avvio dell'installer per l'aggiornamento");
            Process.Start(new ProcessStartInfo(path, InstallerArguments(StartupItem.IsEnabled, L10n.Current)) { UseShellExecute = false });
            InstallerStarted?.Invoke(this, EventArgs.Empty);
        }

        internal static void ShowError(Exception error)
        {
            var answer = MessageBox.Show(
                error.Message + "\n\n" + L10n.T(
                    "Do you want to open the KeepMeOn page on GitHub to download the latest version?",
                    "Vuoi aprire la pagina di KeepMeOn su GitHub per scaricare l'ultima versione?"),
                L10n.T("Update failed", "Aggiornamento non riuscito"),
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning);
            if (answer == DialogResult.Yes)
            {
                Process.Start("https://github.com/christianmusumeci00/KeepMeOn/releases/latest");
            }
        }

        private static HttpClient NewClient()
        {
            var client = new HttpClient { Timeout = TimeSpan.FromMinutes(5) };
            client.DefaultRequestHeaders.UserAgent.ParseAdd("KeepMeOn/" + Assembly.GetExecutingAssembly().GetName().Version.ToString(3));
            return client;
        }

        private void SetBusy(bool busy)
        {
            IsBusy = busy;
            Changed?.Invoke(this, EventArgs.Empty);
        }

        public void Dispose()
        {
            hourly.Dispose();
            firstCheck.Dispose();
        }
    }
}
