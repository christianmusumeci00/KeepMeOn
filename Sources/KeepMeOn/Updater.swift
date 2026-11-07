import AppKit
import Darwin
import KeepMeOnCore
import Security
import SwiftUI

/// Aggiornamenti dalla pagina Release di GitHub.
///
/// - Controllo a mano dal menu, oppure automatico: al massimo una volta al giorno.
/// - Se c'è una versione nuova chiede se installarla. Poi scarica il DMG, verifica che l'app
///   sia firmata come quella in uso (stesso sviluppatore), la mette al posto di quella attuale
///   e riapre KeepMeOn. Impostazioni e permessi restano.
@MainActor
final class Updater: NSObject, ObservableObject {
    static let shared = Updater()

    /// Nome del file della release per il Mac.
    static let assetName = "KeepMeOn.dmg"

    private enum Keys {
        static let automaticChecks = "automaticUpdateChecks"
        static let lastCheck = "lastUpdateCheck"
        /// Versione per cui si è scelto «Non ricordarmelo più».
        static let skippedVersion = "skippedUpdateVersion"
        /// Solo per le prove: `defaults write com.keepmeon.app updateFeedURL file:///percorso/release.json`
        static let feedURL = "updateFeedURL"
    }

    enum UpdateError: LocalizedError {
        case badResponse(Int)
        case notWritable(String)
        case missingApp
        case signatureMismatch
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .badResponse(let status):
                return tr("GitHub responded with code \(status).", "GitHub ha risposto con il codice \(status).")
            case .notWritable(let folder):
                return tr("Can't write to the folder \(folder).", "Non posso scrivere nella cartella \(folder).")
            case .missingApp:
                return tr("The downloaded file doesn't contain KeepMeOn.", "Il file scaricato non contiene KeepMeOn.")
            case .signatureMismatch:
                return tr("The new version isn't signed by the same developer as the installed one.",
                          "La nuova versione non è firmata dallo stesso sviluppatore di quella installata.")
            case .commandFailed(let command):
                return tr("The \(command) command failed.", "Il comando \(command) non è riuscito.")
            }
        }
    }

    @Published var automaticChecks: Bool {
        didSet {
            defaults.set(automaticChecks, forKey: Keys.automaticChecks)
            scheduleAutomaticChecks()
        }
    }

    @Published private(set) var isBusy = false

    let currentVersion: AppVersion

    private let defaults: UserDefaults
    private var timer: Timer?
    private var progressWindow: NSWindow?
    private let progress = UpdateProgress()

    init(defaults: UserDefaults = .standard) {
        defaults.register(defaults: [Keys.automaticChecks: true])
        self.defaults = defaults
        automaticChecks = defaults.bool(forKey: Keys.automaticChecks)
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        currentVersion = AppVersion(shortVersion) ?? AppVersion("0")!
        super.init()
    }

    /// Avvia i controlli automatici, se attivi: il primo poco dopo l'avvio, poi ogni ora
    /// si guarda se è passato un giorno dall'ultimo.
    func start() {
        scheduleAutomaticChecks()
    }

    func checkNow() {
        Task { await check(userInitiated: true) }
    }

    // MARK: Controllo

    private func scheduleAutomaticChecks() {
        timer?.invalidate()
        timer = nil
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(automaticCheck), object: nil)
        guard automaticChecks else { return }

        let timer = Timer(timeInterval: 3600, target: self, selector: #selector(automaticCheck), userInfo: nil, repeats: true)
        timer.tolerance = 600
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        perform(#selector(automaticCheck), with: nil, afterDelay: 30)
    }

    @objc private func automaticCheck() {
        let lastCheck = defaults.object(forKey: Keys.lastCheck) as? Date
        guard automaticChecks, !isBusy, UpdatePolicy.isCheckDue(lastCheck: lastCheck, now: Date()) else { return }
        Task { await check(userInitiated: false) }
    }

    private func check(userInitiated: Bool) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let release = try await fetchLatestRelease()
            defaults.set(Date(), forKey: Keys.lastCheck)
            guard let asset = UpdatePolicy.availableUpdate(in: release, current: currentVersion, assetName: Self.assetName),
                  let version = release.version
            else {
                Log.updater.info("Nessun aggiornamento (in uso \(self.currentVersion.description, privacy: .public), ultima \(release.tagName, privacy: .public))")
                if userInitiated { showUpToDate() }
                return
            }
            let skipped = defaults.string(forKey: Keys.skippedVersion).flatMap { AppVersion($0) }
            guard UpdatePolicy.shouldOffer(version, skipped: skipped, userInitiated: userInitiated) else {
                Log.updater.info("Versione \(version.description, privacy: .public) disponibile, ma da non ricordare")
                return
            }
            Log.updater.info("Disponibile la versione \(version.description, privacy: .public)")
            switch askToInstall(version: version, release: release) {
            case .install:
                defaults.removeObject(forKey: Keys.skippedVersion)
                try await install(asset: asset, version: version)
            case .skip:
                defaults.set(version.description, forKey: Keys.skippedVersion)
                Log.updater.info("Non ricordare più la versione \(version.description, privacy: .public)")
            case .later:
                break
            }
        } catch {
            Log.updater.error("Aggiornamento: \(error.localizedDescription, privacy: .public)")
            hideProgress()
            if userInitiated || error is UpdateError {
                showError(error)
            }
        }
    }

    private func fetchLatestRelease() async throws -> ReleaseInfo {
        let feed = defaults.string(forKey: Keys.feedURL).flatMap(URL.init(string:)) ?? UpdatePolicy.latestReleaseURL
        var request = URLRequest(url: feed, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("KeepMeOn/\(currentVersion.description)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw UpdateError.badResponse(http.statusCode)
        }
        return try ReleaseInfo.decode(data)
    }

    // MARK: Installazione

    private func install(asset: ReleaseInfo.Asset, version: AppVersion) async throws {
        let bundle = Self.installedBundleURL()
        let folder = bundle.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw UpdateError.notWritable(folder.path)
        }

        showProgress(tr("Downloading KeepMeOn \(version.description)…", "Download di KeepMeOn \(version.description)…"))
        let (download, _) = try await URLSession.shared.download(from: asset.downloadURL)
        let dmg = FileManager.default.temporaryDirectory.appendingPathComponent("KeepMeOn-\(version.description).dmg")
        try? FileManager.default.removeItem(at: dmg)
        try FileManager.default.moveItem(at: download, to: dmg)

        progress.status = tr("Verifying and installing…", "Verifica e installazione…")
        let staged = try await Task.detached(priority: .userInitiated) {
            try Updater.stage(dmg: dmg, nextTo: bundle)
        }.value
        try? FileManager.default.removeItem(at: dmg)

        Log.updater.info("Installazione della versione \(version.description, privacy: .public) e riavvio")
        relaunch(replacing: bundle, with: staged)
    }

    /// Dove si trova davvero l'app. Un'app scaricata e aperta senza passare dal Finder (ancora
    /// "in quarantena") viene avviata da macOS da una copia temporanea in sola lettura,
    /// in …/AppTranslocation/…: l'aggiornamento va scritto al posto dell'originale.
    nonisolated static func installedBundleURL() -> URL {
        let running = Bundle.main.bundleURL
        guard running.path.contains("/AppTranslocation/") else { return running }
        if let original = translocationOriginal(of: running) {
            return original
        }
        let applications = URL(fileURLWithPath: "/Applications/KeepMeOn.app")
        return FileManager.default.fileExists(atPath: applications.path) ? applications : running
    }

    /// `SecTranslocateCreateOriginalPathForURL` esiste nel framework Security, ma non negli header pubblici.
    nonisolated private static func translocationOriginal(of url: URL) -> URL? {
        typealias OriginalPath = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
        guard let security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let symbol = dlsym(security, "SecTranslocateCreateOriginalPathForURL")
        else { return nil }
        let originalPath = unsafeBitCast(symbol, to: OriginalPath.self)
        return originalPath(url as CFURL, nil)?.takeRetainedValue() as URL?
    }

    /// Monta il DMG, verifica la firma della nuova app e la copia accanto a quella in uso.
    /// Restituisce il percorso della copia, pronta a prendere il posto dell'app attuale.
    nonisolated private static func stage(dmg: URL, nextTo bundle: URL) throws -> URL {
        let mountPoint = FileManager.default.temporaryDirectory.appendingPathComponent("KeepMeOn-mount-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        try run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mountPoint.path, dmg.path])
        defer {
            try? run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-quiet", "-force"])
            try? FileManager.default.removeItem(at: mountPoint)
        }

        let newApp = mountPoint.appendingPathComponent("KeepMeOn.app")
        guard FileManager.default.fileExists(atPath: newApp.path) else { throw UpdateError.missingApp }
        guard hasSameSigner(newApp) else { throw UpdateError.signatureMismatch }

        let staged = bundle.deletingLastPathComponent().appendingPathComponent(".KeepMeOn-aggiornamento.app")
        try? FileManager.default.removeItem(at: staged)
        try run("/usr/bin/ditto", [newApp.path, staged.path])
        // La firma è verificata: senza la quarantena la nuova copia si apre dal suo posto,
        // non da una copia temporanea, e anche l'aggiornamento successivo può sostituirla.
        try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staged.path])
        return staged
    }

    /// Vero se `app` soddisfa il requisito di firma dell'app in uso: per una copia firmata
    /// Developer ID significa "stesso sviluppatore". Una copia con firma ad-hoc non si aggiorna da sola.
    nonisolated private static func hasSameSigner(_ app: URL) -> Bool {
        var selfCode: SecCode?
        var selfStatic: SecStaticCode?
        var requirement: SecRequirement?
        var newCode: SecStaticCode?
        guard SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode,
              SecCodeCopyStaticCode(selfCode, [], &selfStatic) == errSecSuccess, let selfStatic,
              SecCodeCopyDesignatedRequirement(selfStatic, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(app as CFURL, [], &newCode) == errSecSuccess, let newCode
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(newCode, flags, requirement) == errSecSuccess
    }

    nonisolated private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.commandFailed((tool as NSString).lastPathComponent)
        }
    }

    /// Chiude l'app; un piccolo script attende la chiusura, scambia le due copie e riapre KeepMeOn.
    /// Se lo scambio non riesce, rimette al suo posto la versione precedente.
    private func relaunch(replacing bundle: URL, with staged: URL) {
        let script = """
            while /bin/kill -0 "$1" 2>/dev/null; do /bin/sleep 0.2; done
            old="$2.vecchia-$$"
            if /bin/mv "$2" "$old"; then
              if /bin/mv "$3" "$2"; then /bin/rm -rf "$old"; else /bin/mv "$old" "$2"; fi
            fi
            /usr/bin/open "$2"
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "keepmeon-update", String(ProcessInfo.processInfo.processIdentifier), bundle.path, staged.path]
        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            hideProgress()
            showError(error)
        }
    }

    // MARK: Finestre e avvisi

    private enum Answer {
        case install, later, skip
    }

    private func askToInstall(version: AppVersion, release: ReleaseInfo) -> Answer {
        while true {
            let alert = NSAlert()
            alert.messageText = tr("KeepMeOn \(version.description) is available", "È disponibile KeepMeOn \(version.description)")
            alert.informativeText = tr(
                "You have version \(currentVersion.description). The update downloads from GitHub and installs itself, then KeepMeOn reopens. Your settings and permissions are kept.",
                "Hai la versione \(currentVersion.description). L'aggiornamento si scarica da GitHub e si installa da solo, poi KeepMeOn si riapre. Impostazioni e permessi restano.")
            alert.addButton(withTitle: tr("Install and Relaunch", "Installa e riavvia"))
            alert.addButton(withTitle: tr("Later", "Più tardi"))
            alert.addButton(withTitle: tr("What's New…", "Novità…"))
            alert.addButton(withTitle: tr("Don't Remind Me Again", "Non ricordarmelo più"))
            NSApp.activateIgnoringOtherAppsIfNeeded()
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                return .install
            case .alertThirdButtonReturn:
                NSWorkspace.shared.open(release.pageURL)
            case NSApplication.ModalResponse(rawValue: NSApplication.ModalResponse.alertThirdButtonReturn.rawValue + 1):
                return .skip
            default:
                return .later
            }
        }
    }

    private func showUpToDate() {
        let alert = NSAlert()
        alert.messageText = tr("KeepMeOn is up to date", "KeepMeOn è aggiornata")
        alert.informativeText = tr("You have the latest version, \(currentVersion.description).",
                                   "Hai l'ultima versione disponibile, la \(currentVersion.description).")
        NSApp.activateIgnoringOtherAppsIfNeeded()
        alert.runModal()
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = tr("Update failed", "Aggiornamento non riuscito")
        alert.informativeText = error.localizedDescription + "\n\n" + tr(
            "You can download the latest version from the KeepMeOn page on GitHub.",
            "Puoi scaricare l'ultima versione dalla pagina di KeepMeOn su GitHub.")
        alert.addButton(withTitle: tr("Open GitHub", "Apri GitHub"))
        alert.addButton(withTitle: "OK")
        NSApp.activateIgnoringOtherAppsIfNeeded()
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/christianmusumeci00/KeepMeOn/releases/latest")!)
        }
    }

    private func showProgress(_ status: String) {
        progress.status = status
        if progressWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: UpdateProgressView(progress: progress)))
            window.title = tr("Updating KeepMeOn", "Aggiornamento di KeepMeOn")
            window.styleMask = [.titled]
            window.isReleasedWhenClosed = false
            window.center()
            progressWindow = window
        }
        NSApp.activateIgnoringOtherAppsIfNeeded()
        progressWindow?.makeKeyAndOrderFront(nil)
    }

    private func hideProgress() {
        progressWindow?.orderOut(nil)
    }
}

/// Testo della finestra di avanzamento.
@MainActor
final class UpdateProgress: ObservableObject {
    @Published var status = ""
}

private struct UpdateProgressView: View {
    @ObservedObject var progress: UpdateProgress

    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.small)
            Text(progress.status)
        }
        .padding(24)
        .frame(width: 360, alignment: .leading)
    }
}
