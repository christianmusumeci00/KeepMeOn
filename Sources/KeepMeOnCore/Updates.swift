import Foundation

/// Numero di versione come "1.2.0" o "v1.2.0", confrontato componente per componente
/// ("1.2" e "1.2.0" sono uguali). Un suffisso come "-beta" viene ignorato.
public struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    public let components: [Int]

    public init?(_ text: String) {
        var core = Substring(text.trimmingCharacters(in: .whitespaces))
        if core.first == "v" || core.first == "V" {
            core = core.dropFirst()
        }
        core = core.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        let parts = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        components = parts.map { $0! }
    }

    public var description: String {
        components.map(String.init).joined(separator: ".")
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        compare(lhs, rhs) == 0
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        compare(lhs, rhs) < 0
    }

    private static func compare(_ lhs: AppVersion, _ rhs: AppVersion) -> Int {
        for index in 0..<max(lhs.components.count, rhs.components.count) {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right ? -1 : 1 }
        }
        return 0
    }
}

/// Ultima release pubblicata su GitHub: risposta di `GET /repos/{owner}/{repo}/releases/latest`.
public struct ReleaseInfo: Decodable, Sendable {
    public struct Asset: Decodable, Sendable {
        public let name: String
        public let downloadURL: URL
        public let size: Int

        enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
            case size
        }
    }

    public let tagName: String
    public let pageURL: URL
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case pageURL = "html_url"
        case assets
    }

    public static func decode(_ data: Data) throws -> ReleaseInfo {
        try JSONDecoder().decode(ReleaseInfo.self, from: data)
    }

    public var version: AppVersion? {
        AppVersion(tagName)
    }

    public func asset(named name: String) -> Asset? {
        assets.first { $0.name == name }
    }
}

/// Regole degli aggiornamenti, come funzioni pure.
public enum UpdatePolicy {
    /// Ultima release pubblicata (le pre-release e le bozze sono escluse da GitHub).
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/christianmusumeci00/KeepMeOn/releases/latest")!

    /// Il controllo automatico avviene al massimo una volta al giorno.
    public static let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    /// Il file da installare, se la release è più recente della versione in uso e lo contiene.
    public static func availableUpdate(in release: ReleaseInfo, current: AppVersion, assetName: String) -> ReleaseInfo.Asset? {
        guard let latest = release.version, latest > current else { return nil }
        return release.asset(named: assetName)
    }

    /// Vero se la versione va proposta. Per una versione con «Non ricordarmelo più» il controllo
    /// automatico tace; il controllo dal menu la mostra comunque. Una versione più recente si propone di nuovo.
    public static func shouldOffer(_ version: AppVersion, skipped: AppVersion?, userInitiated: Bool) -> Bool {
        guard !userInitiated, let skipped else { return true }
        return version > skipped
    }

    /// Vero se è ora di un controllo automatico.
    public static func isCheckDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= automaticCheckInterval || now < lastCheck
    }
}
