using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using KeepMeOn.Core;
using Microsoft.Win32;
using static KeepMeOn.NativeMethods;

namespace KeepMeOn.Probe
{
    /// <summary>
    /// Verifiche su un Windows vero (GitHub Actions):
    ///   input                 prova i segnali neutri e controlla che azzerino il contatore di inattività
    ///   snapshots &lt;cartella&gt;  salva le immagini della configurazione guidata, degli orari, del menu e delle icone
    ///   update &lt;setup.exe&gt;    legge la release da GitHub e prova l'installazione silenziosa usata dagli aggiornamenti
    /// </summary>
    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            switch (args.Length > 0 ? args[0] : "")
            {
                case "input":
                    return Input();
                case "snapshots":
                    return Snapshots(args.Length > 1 ? args[1] : "snapshots");
                case "update":
                    return Update(args[1]);
                default:
                    Console.Error.WriteLine("Uso: KeepMeOn.Probe input | snapshots <cartella> | update <setup.exe>");
                    return 2;
            }
        }

        // Segnale neutro.

        /// <summary>Esce con 0 solo se il segnale usato dall'app azzera il contatore senza muovere il cursore.</summary>
        private static int Input()
        {
            Console.WriteLine($"Sessione interattiva: {Environment.UserInteractive}, processo a 64 bit: {Environment.Is64BitProcess}, " +
                              $"dimensione di INPUT: {Marshal.SizeOf(typeof(INPUT))} byte");

            var candidates = new (string Name, Func<bool> Send, bool UsedByApp)[]
            {
                ("rilascio di un tasto non assegnato", ActivityKeeper.SendUnassignedKeyUp, true),
                ("mouse fermo, spostamento 0,0", ActivityKeeper.SendZeroMouseMove, false),
                ("solo SetThreadExecutionState", ActivityKeeper.DeclareActivity, false),
            };

            bool appSignalWorks = false;
            foreach (var candidate in candidates)
            {
                Thread.Sleep(3000);
                TimeSpan before = ActivityKeeper.IdleTime;
                GetCursorPos(out POINT cursorBefore);
                bool sent = candidate.Send();
                Thread.Sleep(300);
                TimeSpan after = ActivityKeeper.IdleTime;
                GetCursorPos(out POINT cursorAfter);

                bool reset = after.TotalSeconds < before.TotalSeconds - 1;
                bool cursorStill = cursorBefore.X == cursorAfter.X && cursorBefore.Y == cursorAfter.Y;
                Console.WriteLine($"{candidate.Name}: inviato={sent}, inattività {before.TotalSeconds:0.00} s → {after.TotalSeconds:0.00} s, " +
                                  $"azzerata={reset}, cursore fermo={cursorStill}");
                if (candidate.UsedByApp)
                {
                    appSignalWorks = sent && reset && cursorStill;
                }
            }

            Console.WriteLine(appSignalWorks ? "Esito: il segnale dell'app funziona." : "Esito: il segnale dell'app NON azzera il contatore.");
            return appSignalWorks ? 0 : 1;
        }

        // Aggiornamenti.

        /// <summary>
        /// Release reale su GitHub e installazione silenziosa con gli stessi parametri dell'app,
        /// con e senza avvio all'accesso. Alla fine disinstalla.
        /// </summary>
        private static int Update(string setup)
        {
            bool ok = true;

            var release = Updater.FetchLatestReleaseAsync(token: Environment.GetEnvironmentVariable("GH_TOKEN")).GetAwaiter().GetResult();
            var asset = UpdatePolicy.AvailableUpdate(release, AppVersion.Parse("1.0.0"), Updater.AssetName);
            Console.WriteLine($"GitHub: ultima release {release.TagName}, file per Windows: {asset?.DownloadUrl ?? "assente"}");
            ok &= asset != null;

            string folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "KeepMeOn");
            string exe = Path.Combine(folder, "KeepMeOn.exe");
            foreach (bool startup in new[] { false, true })
            {
                var install = Process.Start(new ProcessStartInfo(Path.GetFullPath(setup), Updater.InstallerArguments(startup)) { UseShellExecute = false });
                install.WaitForExit();
                Thread.Sleep(4000);
                bool installed = File.Exists(exe);
                bool runKey = RunKeyPresent();
                var running = Process.GetProcessesByName("KeepMeOn");
                Console.WriteLine($"Installazione silenziosa, avvio all'accesso {(startup ? "sì" : "no")}: uscita {install.ExitCode}, " +
                                  $"installata={installed}, avvio all'accesso={runKey}, riaperta={running.Length > 0}");
                ok &= install.ExitCode == 0 && installed && runKey == startup && running.Length > 0;
                foreach (var process in running)
                {
                    process.Kill();
                    process.WaitForExit();
                }
            }
            if (File.Exists(exe))
            {
                Console.WriteLine($"Versione installata: {FileVersionInfo.GetVersionInfo(exe).FileVersion}");
            }

            var uninstall = Process.Start(new ProcessStartInfo(Path.Combine(folder, "unins000.exe"), "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART") { UseShellExecute = false });
            uninstall.WaitForExit();
            Thread.Sleep(3000);
            bool removed = !File.Exists(exe) && !RunKeyPresent();
            Console.WriteLine($"Disinstallazione: uscita {uninstall.ExitCode}, app e avvio all'accesso rimossi={removed}");
            ok &= removed;

            Console.WriteLine(ok ? "Esito: aggiornamenti e installazione silenziosa funzionano." : "Esito: qualcosa NON funziona.");
            return ok ? 0 : 1;
        }

        private static bool RunKeyPresent()
        {
            using (var run = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"))
            {
                return run?.GetValue("KeepMeOn") != null;
            }
        }

        // Immagini.

        private static int Snapshots(string folder)
        {
            Directory.CreateDirectory(folder);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            SynchronizationContext.SetSynchronizationContext(new WindowsFormsSynchronizationContext());

            // Impostazioni in una chiave a parte, cancellata alla fine.
            var settings = new SettingsStore(@"Software\KeepMeOn.Probe") { WorkHoursOnly = true, LunchBreakEnabled = true };
            try
            {
                using (var controller = new KeeperController(settings))
                using (var updater = new Updater(settings))
                {
                    using (var onboarding = new OnboardingForm(controller, updater))
                    {
                        Open(onboarding);
                        string[] names = { "benvenuto", "quando", "pausa-pranzo", "avvio", "pronto" };
                        for (int i = 0; i < names.Length; i++)
                        {
                            onboarding.GoTo(i);
                            Pump();
                            Snap(onboarding, folder, $"guida-{i + 1}-{names[i]}");
                        }
                        onboarding.Close();
                    }

                    using (var form = new SettingsForm(controller))
                    {
                        Open(form);
                        Snap(form, folder, "orari");
                        form.Close();
                    }

                    var release = ReleaseInfo.Parse(@"{""tag_name"": ""v1.3.0"", ""html_url"": ""https://github.com/christianmusumeci00/KeepMeOn/releases"",
                        ""assets"": [{""name"": ""KeepMeOn-Setup.exe"", ""size"": 1, ""browser_download_url"": ""https://example.invalid/KeepMeOn-Setup.exe""}]}");
                    using (var form = new UpdateForm(updater, release, release.Asset(Updater.AssetName)))
                    {
                        Open(form);
                        Snap(form, folder, "aggiornamento");
                        form.Close();
                    }

                    using (var menu = new TrayMenu(controller, updater))
                    {
                        menu.Menu.Show(new Point(300, 200));
                        Pump();
                        SaveScreen(menu.Menu.Bounds, folder, "menu");
                        menu.Menu.Close();
                    }
                    SaveTrayIcons(folder);
                }
            }
            finally
            {
                settings.DeleteAll();
            }
            Console.WriteLine($"Immagini salvate in {Path.GetFullPath(folder)}");
            return 0;
        }

        private static void Open(Form form)
        {
            form.StartPosition = FormStartPosition.Manual;
            form.Location = new Point(40, 40);
            form.Show();
            Pump();
        }

        private static void Snap(Form form, string folder, string name)
        {
            Rectangle visible = VisibleBounds(form);
            SaveScreen(visible, folder, name);
            Console.WriteLine($"{name}: {visible.Width}×{visible.Height}");
        }

        /// <summary>
        /// Area davvero visibile della finestra: Windows 10 e 11 aggiungono bordi invisibili
        /// per il ridimensionamento, che in una cattura mostrerebbero lo sfondo.
        /// </summary>
        private static Rectangle VisibleBounds(Form form)
        {
            const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;
            return DwmGetWindowAttribute(form.Handle, DWMWA_EXTENDED_FRAME_BOUNDS, out RECT rect, Marshal.SizeOf(typeof(RECT))) == 0
                ? Rectangle.FromLTRB(rect.Left, rect.Top, rect.Right, rect.Bottom)
                : form.Bounds;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [DllImport("dwmapi.dll")]
        private static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out RECT value, int size);

        /// <summary>Cattura una zona dello schermo: mostra la finestra come la vede l'utente, ombre e temi compresi.</summary>
        private static void SaveScreen(Rectangle bounds, string folder, string name)
        {
            try
            {
                using (var bitmap = new Bitmap(bounds.Width, bounds.Height))
                using (var graphics = Graphics.FromImage(bitmap))
                {
                    graphics.CopyFromScreen(bounds.Location, Point.Empty, bounds.Size);
                    bitmap.Save(Path.Combine(folder, name + ".png"), ImageFormat.Png);
                }
            }
            catch (Exception e)
            {
                Console.WriteLine($"{name}: cattura dello schermo non riuscita ({e.Message})");
            }
        }

        /// <summary>Le tre icone dell'area di notifica a 16, 24 e 32 px, su barra chiara e scura.</summary>
        private static void SaveTrayIcons(string folder)
        {
            string[] names = { "TrayCovering", "TrayPaused", "TrayOff" };
            int[] sizes = { 16, 24, 32 };
            const int cell = 48;
            using (var bitmap = new Bitmap(cell * names.Length * sizes.Length, cell * 2))
            using (var graphics = Graphics.FromImage(bitmap))
            {
                graphics.FillRectangle(new SolidBrush(Color.FromArgb(243, 243, 243)), 0, 0, bitmap.Width, cell);
                graphics.FillRectangle(new SolidBrush(Color.FromArgb(32, 32, 32)), 0, cell, bitmap.Width, cell);
                for (int row = 0; row < 2; row++)
                {
                    int column = 0;
                    foreach (string name in names)
                    {
                        foreach (int size in sizes)
                        {
                            using (var icon = Ui.LoadIcon(name, new Size(size, size)))
                            {
                                int x = column * cell + (cell - size) / 2;
                                int y = row * cell + (cell - size) / 2;
                                graphics.DrawIcon(icon, new Rectangle(x, y, size, size));
                            }
                            column++;
                        }
                    }
                }
                bitmap.Save(Path.Combine(folder, "icone-area-notifica.png"), ImageFormat.Png);
            }
        }

        private static void Pump()
        {
            for (int i = 0; i < 20; i++)
            {
                Application.DoEvents();
                Thread.Sleep(50);
            }
        }
    }
}
