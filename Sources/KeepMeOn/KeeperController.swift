import AppKit
import KeepMeOnCore

/// Collega impostazioni, eventi di sistema e timer, e decide quando `ActivityKeeper` deve agire.
///
/// Un solo timer, attivo solo quando serve: si ferma se l'app è disattivata,
/// lo schermo è bloccato, il Mac è in stop o gli schermi sono spenti.
@MainActor
final class KeeperController: NSObject, ObservableObject {
    /// Istanza dell'app, condivisa da menu, finestre e delegate.
    static let shared = KeeperController()

    /// Intervalli di controllo proposti nel menu, in secondi.
    static let intervalOptions = [30, 60, 120, 240]

    private enum Keys {
        static let enabled = "enabled"
        static let interval = "intervalSeconds"
        static let workHoursOnly = "workHoursOnly"
        static let workStart = "workStartMinute"
        static let workEnd = "workEndMinute"
        static let workDays = "workWeekdayMask"
        static let lunchEnabled = "lunchBreakEnabled"
        static let lunchStart = "lunchStartMinute"
        static let lunchEnd = "lunchEndMinute"
        /// Senza voce nel menu: `defaults write com.keepmeon.app idleThresholdSeconds -int 90`
        static let idleThreshold = "idleThresholdSeconds"
        /// Riavvio automatico già tentato e permesso non ancora ottenuto: niente altri riavvii.
        static let permissionRelaunchTried = "permissionRelaunchTried"
    }

    private static let accessibilitySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    // MARK: Impostazioni, salvate in UserDefaults

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled); reconcile() }
    }

    @Published var interval: Int {
        didSet { defaults.set(interval, forKey: Keys.interval); reconcile() }
    }

    @Published var workHoursOnly: Bool {
        didSet { defaults.set(workHoursOnly, forKey: Keys.workHoursOnly); reconcile() }
    }

    @Published var workHours: WorkHours {
        didSet {
            defaults.set(workHours.startMinute, forKey: Keys.workStart)
            defaults.set(workHours.endMinute, forKey: Keys.workEnd)
            defaults.set(workHours.weekdayMask, forKey: Keys.workDays)
            reconcile()
        }
    }

    @Published var lunchBreakEnabled: Bool {
        didSet { defaults.set(lunchBreakEnabled, forKey: Keys.lunchEnabled); reconcile() }
    }

    @Published var lunchBreak: LunchBreak {
        didSet {
            defaults.set(lunchBreak.startMinute, forKey: Keys.lunchStart)
            defaults.set(lunchBreak.endMinute, forKey: Keys.lunchEnd)
            reconcile()
        }
    }

    // MARK: Stato

    @Published private(set) var state: KeeperState = .off
    @Published private(set) var lastDeclaration: Date?
    /// Permesso di Accessibilità, necessario perché Teams resti verde.
    @Published private(set) var hasEventAccess: Bool

    private var isScreenLocked = false
    private var isSystemAsleep = false
    private var areDisplaysAsleep = false

    private let keeper = ActivityKeeper()
    private let defaults: UserDefaults
    private var timer: Timer?
    /// Impedisce ad App Nap di rallentare il timer mentre l'app non ha finestre visibili.
    private var appNapGuard: NSObjectProtocol?

    /// Soglia impostata dall'utente; `Scheduler.idleThreshold` la abbassa per gli intervalli lunghi.
    private var baseIdleThreshold: TimeInterval {
        let value = defaults.double(forKey: Keys.idleThreshold)
        return value > 0 ? value : Scheduler.defaultIdleThreshold
    }

    init(defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Keys.enabled: true,
            Keys.interval: 60,
            Keys.workHoursOnly: false,
            Keys.workStart: WorkHours.standard.startMinute,
            Keys.workEnd: WorkHours.standard.endMinute,
            Keys.workDays: WorkHours.standard.weekdayMask,
            Keys.lunchEnabled: false,
            Keys.lunchStart: LunchBreak.standard.startMinute,
            Keys.lunchEnd: LunchBreak.standard.endMinute,
            Keys.idleThreshold: Scheduler.defaultIdleThreshold,
        ])
        self.defaults = defaults

        let storedInterval = defaults.integer(forKey: Keys.interval)
        isEnabled = defaults.bool(forKey: Keys.enabled)
        interval = Self.intervalOptions.contains(storedInterval) ? storedInterval : 60
        workHoursOnly = defaults.bool(forKey: Keys.workHoursOnly)
        workHours = WorkHours(
            startMinute: defaults.integer(forKey: Keys.workStart),
            endMinute: defaults.integer(forKey: Keys.workEnd),
            weekdayMask: defaults.integer(forKey: Keys.workDays)
        )
        lunchBreakEnabled = defaults.bool(forKey: Keys.lunchEnabled)
        lunchBreak = LunchBreak(
            startMinute: defaults.integer(forKey: Keys.lunchStart),
            endMinute: defaults.integer(forKey: Keys.lunchEnd)
        )
        hasEventAccess = ActivityKeeper.canPostEvents
        super.init()

        observeSystemEvents()
        reconcile()
    }

    // MARK: Permesso di Accessibilità

    /// Aggiunge KeepMeOn all'elenco Accessibilità e apre la pagina di Impostazioni di Sistema.
    func requestEventAccess() {
        ActivityKeeper.requestEventAccess()
        NSWorkspace.shared.open(Self.accessibilitySettingsURL)
    }

    @objc private func refreshEventAccess() {
        let granted = ActivityKeeper.canPostEvents
        if granted {
            defaults.removeObject(forKey: Keys.permissionRelaunchTried)
        } else if ActivityKeeper.isAccessibilityTrusted {
            // Interruttore attivato ad app avviata: l'invio di eventi si sblocca solo al prossimo avvio.
            relaunchToApplyPermission()
            return
        }
        guard granted != hasEventAccess else { return }
        Log.keeper.info("Permesso di Accessibilità: \(granted ? "concesso" : "assente", privacy: .public)")
        hasEventAccess = granted
    }

    /// Chiude l'app e la riapre. Un solo tentativo finché il permesso non risulta attivo,
    /// così un permesso negato non provoca riavvii a ripetizione.
    private func relaunchToApplyPermission() {
        guard !defaults.bool(forKey: Keys.permissionRelaunchTried) else { return }
        defaults.set(true, forKey: Keys.permissionRelaunchTried)
        Log.keeper.info("Permesso concesso: riavvio per applicarlo")

        // Attende la chiusura di questo processo ($1), poi riapre il bundle ($0).
        let relauncher = Process()
        relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
        relauncher.arguments = [
            "-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"",
            Bundle.main.bundlePath, String(ProcessInfo.processInfo.processIdentifier),
        ]
        do {
            try relauncher.run()
            NSApp.terminate(nil)
        } catch {
            Log.keeper.error("Riavvio non riuscito: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Timer e controllo

    /// Riallinea timer e stato dopo ogni cambio di impostazioni o evento di sistema.
    private func reconcile() {
        let shouldRun = isEnabled && !isScreenLocked && !isSystemAsleep && !areDisplaysAsleep
        if !shouldRun {
            stopTimer()
        } else if timer?.timeInterval != TimeInterval(interval) {
            startTimer()
        }
        check()
    }

    private func startTimer() {
        stopTimer()
        let seconds = TimeInterval(interval)
        let timer = Timer(timeInterval: seconds, target: self, selector: #selector(timerFired(_:)),
                          userInfo: nil, repeats: true)
        timer.tolerance = Scheduler.timerTolerance(forInterval: seconds)
        // `.common`: scatta anche mentre il menu è aperto.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        if appNapGuard == nil {
            appNapGuard = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Controllo periodico dell'inattività"
            )
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        if let appNapGuard {
            ProcessInfo.processInfo.endActivity(appNapGuard)
            self.appNapGuard = nil
        }
    }

    @objc private func timerFired(_ timer: Timer) {
        check()
    }

    /// Aggiorna lo stato e, se l'utente è fermo da oltre la soglia, dichiara attività.
    private func check() {
        refreshEventAccess()

        let newState = Scheduler.state(
            isEnabled: isEnabled,
            isAsleep: isSystemAsleep || areDisplaysAsleep,
            isScreenLocked: isScreenLocked,
            workHoursOnly: workHoursOnly,
            workHours: workHours,
            lunchBreak: lunchBreakEnabled ? lunchBreak : nil,
            now: Date()
        )
        if newState != state {
            Log.keeper.info("Stato: \(String(describing: newState), privacy: .public)")
            state = newState
        }

        guard newState == .active else {
            keeper.release()
            return
        }

        let idle = ActivityKeeper.systemIdleSeconds()
        let threshold = Scheduler.idleThreshold(base: baseIdleThreshold, interval: TimeInterval(interval))
        guard Scheduler.shouldDeclareActivity(idleSeconds: idle, threshold: threshold) else { return }

        let declared = keeper.declareActivity()
        let posted = keeper.postNeutralEvent()
        if declared || posted {
            lastDeclaration = Date()
        }
        Log.keeper.debug("""
            Inattivo da \(Int(idle), privacy: .public) s: \
            powerd \(declared ? "ok" : "errore", privacy: .public), \
            evento \(posted ? "inviato" : "non inviato", privacy: .public)
            """)
    }

    // MARK: Eventi di sistema

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemWillSleep(_:)),
                              name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemDidWake(_:)),
                              name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(displaysDidSleep(_:)),
                              name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(displaysDidWake(_:)),
                              name: NSWorkspace.screensDidWakeNotification, object: nil)

        // `.deliverImmediately`: AppKit sospende le notifiche distribuite quando l'app
        // non è in primo piano, cioè quasi sempre per un'app da barra dei menu.
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screenDidLock(_:)),
                                name: .init("com.apple.screenIsLocked"), object: nil,
                                suspensionBehavior: .deliverImmediately)
        distributed.addObserver(self, selector: #selector(screenDidUnlock(_:)),
                                name: .init("com.apple.screenIsUnlocked"), object: nil,
                                suspensionBehavior: .deliverImmediately)
        // Inviata quando cambia l'elenco Accessibilità.
        distributed.addObserver(self, selector: #selector(accessibilityListDidChange(_:)),
                                name: .init("com.apple.accessibility.api"), object: nil,
                                suspensionBehavior: .deliverImmediately)

        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate(_:)),
                                               name: NSApplication.willTerminateNotification, object: nil)
    }

    @objc private func systemWillSleep(_ note: Notification) {
        isSystemAsleep = true
        reconcile()
    }

    @objc private func systemDidWake(_ note: Notification) {
        isSystemAsleep = false
        reconcile()
    }

    @objc private func displaysDidSleep(_ note: Notification) {
        areDisplaysAsleep = true
        reconcile()
    }

    @objc private func displaysDidWake(_ note: Notification) {
        areDisplaysAsleep = false
        reconcile()
    }

    @objc private func screenDidLock(_ note: Notification) {
        isScreenLocked = true
        reconcile()
    }

    @objc private func screenDidUnlock(_ note: Notification) {
        isScreenLocked = false
        reconcile()
    }

    @objc private func accessibilityListDidChange(_ note: Notification) {
        // Il database dei permessi si aggiorna un attimo dopo la notifica.
        perform(#selector(refreshEventAccess), with: nil, afterDelay: 1)
    }

    @objc private func appWillTerminate(_ note: Notification) {
        stopTimer()
        keeper.release()
    }
}
