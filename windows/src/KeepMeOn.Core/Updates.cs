using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Text;

namespace KeepMeOn.Core
{
    /// <summary>
    /// Numero di versione come "1.2.0" o "v1.2.0", confrontato componente per componente
    /// ("1.2" e "1.2.0" sono uguali). Un suffisso come "-beta" viene ignorato.
    /// </summary>
    public sealed class AppVersion : IComparable<AppVersion>, IEquatable<AppVersion>
    {
        private AppVersion(IReadOnlyList<int> components)
        {
            Components = components;
        }

        public IReadOnlyList<int> Components { get; }

        public static AppVersion Parse(string text)
        {
            string core = (text ?? "").Trim();
            if (core.StartsWith("v", StringComparison.OrdinalIgnoreCase))
            {
                core = core.Substring(1);
            }
            int dash = core.IndexOf('-');
            if (dash >= 0)
            {
                core = core.Substring(0, dash);
            }
            var parts = core.Split('.');
            var numbers = new List<int>();
            foreach (string part in parts)
            {
                if (!int.TryParse(part, out int number) || number < 0 || part.Length == 0)
                {
                    return null;
                }
                numbers.Add(number);
            }
            return numbers.Count == 0 ? null : new AppVersion(numbers);
        }

        public static AppVersion FromSystemVersion(Version version) =>
            new AppVersion(new[] { version.Major, version.Minor, Math.Max(version.Build, 0) });

        public int CompareTo(AppVersion other)
        {
            if (other == null) return 1;
            int count = Math.Max(Components.Count, other.Components.Count);
            for (int i = 0; i < count; i++)
            {
                int left = i < Components.Count ? Components[i] : 0;
                int right = i < other.Components.Count ? other.Components[i] : 0;
                if (left != right) return left < right ? -1 : 1;
            }
            return 0;
        }

        public bool Equals(AppVersion other) => CompareTo(other) == 0;

        public override bool Equals(object obj) => Equals(obj as AppVersion);

        public override int GetHashCode() => Components.Reverse().SkipWhile(c => c == 0).Aggregate(17, (hash, c) => hash * 31 + c);

        public override string ToString() => string.Join(".", Components);
    }

    /// <summary>Ultima release pubblicata su GitHub: risposta di GET /repos/{owner}/{repo}/releases/latest.</summary>
    public sealed class ReleaseInfo
    {
        public string TagName { get; private set; }

        public string PageUrl { get; private set; }

        public IReadOnlyList<ReleaseAsset> Assets { get; private set; }

        public AppVersion Version => AppVersion.Parse(TagName);

        public ReleaseAsset Asset(string name) => Assets.FirstOrDefault(asset => asset.Name == name);

        public static ReleaseInfo Parse(string json)
        {
            var serializer = new DataContractJsonSerializer(typeof(ReleaseJson));
            using (var stream = new MemoryStream(Encoding.UTF8.GetBytes(json)))
            {
                var release = (ReleaseJson)serializer.ReadObject(stream);
                return new ReleaseInfo
                {
                    TagName = release.TagName ?? "",
                    PageUrl = release.HtmlUrl ?? "",
                    Assets = (release.Assets ?? new AssetJson[0])
                        .Select(asset => new ReleaseAsset(asset.Name ?? "", asset.DownloadUrl ?? "", asset.Size))
                        .ToList(),
                };
            }
        }

        [DataContract]
        private sealed class ReleaseJson
        {
            [DataMember(Name = "tag_name")] public string TagName { get; set; }
            [DataMember(Name = "html_url")] public string HtmlUrl { get; set; }
            [DataMember(Name = "assets")] public AssetJson[] Assets { get; set; }
        }

        [DataContract]
        private sealed class AssetJson
        {
            [DataMember(Name = "name")] public string Name { get; set; }
            [DataMember(Name = "browser_download_url")] public string DownloadUrl { get; set; }
            [DataMember(Name = "size")] public long Size { get; set; }
        }
    }

    public sealed class ReleaseAsset
    {
        public ReleaseAsset(string name, string downloadUrl, long size)
        {
            Name = name;
            DownloadUrl = downloadUrl;
            Size = size;
        }

        public string Name { get; }

        public string DownloadUrl { get; }

        public long Size { get; }
    }

    /// <summary>Regole degli aggiornamenti, come funzioni pure.</summary>
    public static class UpdatePolicy
    {
        /// <summary>Ultima release pubblicata (le pre-release e le bozze sono escluse da GitHub).</summary>
        public const string LatestReleaseUrl = "https://api.github.com/repos/christianmusumeci00/KeepMeOn/releases/latest";

        /// <summary>Il controllo automatico avviene al massimo una volta al giorno.</summary>
        public static readonly TimeSpan AutomaticCheckInterval = TimeSpan.FromHours(24);

        /// <summary>Il file da installare, se la release è più recente della versione in uso e lo contiene.</summary>
        public static ReleaseAsset AvailableUpdate(ReleaseInfo release, AppVersion current, string assetName)
        {
            var latest = release.Version;
            if (latest == null || latest.CompareTo(current) <= 0)
            {
                return null;
            }
            return release.Asset(assetName);
        }

        /// <summary>Vero se è ora di un controllo automatico.</summary>
        public static bool IsCheckDue(DateTime? lastCheck, DateTime now) =>
            lastCheck == null || now - lastCheck.Value >= AutomaticCheckInterval || now < lastCheck.Value;
    }
}
