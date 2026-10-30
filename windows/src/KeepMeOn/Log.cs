using System;
using System.IO;

namespace KeepMeOn
{
    /// <summary>
    /// Registro breve in %LOCALAPPDATA%\KeepMeOn\keepmeon.log: stati e interventi, utile per capire
    /// cosa è successo se Teams è diventato giallo. Oltre 256 KB il file diventa keepmeon.old.log.
    /// </summary>
    internal static class Log
    {
        private const long MaxBytes = 256 * 1024;

        private static readonly string Folder =
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "KeepMeOn");

        public static readonly string FilePath = Path.Combine(Folder, "keepmeon.log");

        public static void Write(string message)
        {
            try
            {
                Directory.CreateDirectory(Folder);
                var file = new FileInfo(FilePath);
                if (file.Exists && file.Length > MaxBytes)
                {
                    string old = Path.Combine(Folder, "keepmeon.old.log");
                    File.Delete(old);
                    File.Move(FilePath, old);
                }
                File.AppendAllText(FilePath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss}  {message}{Environment.NewLine}");
            }
            catch (IOException)
            {
                // Il registro è un aiuto, non deve mai fermare l'app.
            }
            catch (UnauthorizedAccessException)
            {
            }
        }
    }
}
