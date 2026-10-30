using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using static KeepMeOn.NativeMethods;

namespace KeepMeOn.Probe
{
    /// <summary>
    /// Verifiche su un Windows vero (GitHub Actions):
    ///   input                 prova i segnali neutri e controlla che azzerino il contatore di inattività
    ///   snapshots &lt;cartella&gt;  salva le immagini di benvenuto, orari, menu e icone
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
                default:
                    Console.Error.WriteLine("Uso: KeepMeOn.Probe input | snapshots <cartella>");
                    return 2;
            }
        }

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
                {
                    Capture(new WelcomeForm(), folder, "benvenuto");
                    Capture(new SettingsForm(controller), folder, "orari");
                    using (var menu = new TrayMenu(controller))
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

        private static void Capture(Form form, string folder, string name)
        {
            form.StartPosition = FormStartPosition.Manual;
            form.Location = new Point(40, 40);
            form.Show();
            Pump();
            using (var bitmap = new Bitmap(form.Width, form.Height))
            {
                form.DrawToBitmap(bitmap, new Rectangle(Point.Empty, form.Size));
                bitmap.Save(Path.Combine(folder, name + ".png"), ImageFormat.Png);
            }
            SaveScreen(form.Bounds, folder, name + "-schermo");
            Console.WriteLine($"{name}: {form.Width}×{form.Height}");
            form.Close();
        }

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
