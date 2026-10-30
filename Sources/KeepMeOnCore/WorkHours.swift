import Foundation

/// Fascia oraria di lavoro: ora di inizio, ora di fine e giorni della settimana.
///
/// - I giorni usano la numerazione di `Calendar`: 1 = domenica … 7 = sabato.
/// - L'inizio è incluso, la fine esclusa (09:00–18:00 vale fino alle 17:59).
/// - Se la fine viene prima dell'inizio la fascia scavalca la mezzanotte
///   (es. 22:00–06:00): la parte dopo mezzanotte appartiene al giorno in cui è iniziata.
/// - Se inizio e fine coincidono la fascia copre l'intera giornata.
public struct WorkHours: Equatable, Sendable {
    public static let minutesPerDay = 24 * 60

    /// Minuti dalla mezzanotte, 0…1439.
    public var startMinute: Int
    public var endMinute: Int
    public var weekdays: Set<Int>

    /// Predefinita: lunedì–venerdì, 09:00–18:00.
    public static let standard = WorkHours(startMinute: 9 * 60, endMinute: 18 * 60, weekdays: [2, 3, 4, 5, 6])

    public init(startMinute: Int, endMinute: Int, weekdays: Set<Int>) {
        self.startMinute = Self.clamped(startMinute)
        self.endMinute = Self.clamped(endMinute)
        self.weekdays = weekdays.filter { (1...7).contains($0) }
    }

    /// Vero se `date` cade nella fascia. È la funzione pura usata per decidere se agire.
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = parts.weekday, let hour = parts.hour, let minute = parts.minute else { return false }
        let now = hour * 60 + minute

        if startMinute == endMinute {
            return weekdays.contains(weekday)
        }
        if startMinute < endMinute {
            return weekdays.contains(weekday) && (startMinute..<endMinute).contains(now)
        }
        // Fascia a cavallo della mezzanotte.
        if now >= startMinute {
            return weekdays.contains(weekday)
        }
        if now < endMinute {
            return weekdays.contains(Self.weekday(before: weekday))
        }
        return false
    }

    private static func clamped(_ minute: Int) -> Int {
        min(max(minute, 0), minutesPerDay - 1)
    }

    private static func weekday(before weekday: Int) -> Int {
        weekday == 1 ? 7 : weekday - 1
    }
}

// MARK: - Persistenza

extension WorkHours {
    /// Giorni come bitmask (bit 0 = domenica … bit 6 = sabato), comoda da salvare in UserDefaults.
    public var weekdayMask: Int {
        weekdays.reduce(0) { $0 | (1 << ($1 - 1)) }
    }

    public init(startMinute: Int, endMinute: Int, weekdayMask: Int) {
        let days = (1...7).filter { weekdayMask & (1 << ($0 - 1)) != 0 }
        self.init(startMinute: startMinute, endMinute: endMinute, weekdays: Set(days))
    }
}

// MARK: - Testi per l'interfaccia

extension WorkHours {
    /// Ordine di visualizzazione dei giorni, da lunedì a domenica.
    public static let mondayFirst = [2, 3, 4, 5, 6, 7, 1]

    public static func shortName(of weekday: Int) -> String {
        ["dom", "lun", "mar", "mer", "gio", "ven", "sab"][weekday - 1]
    }

    public static func timeString(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    /// Descrizione breve, es. "lun–ven, 09:00–18:00".
    public var summary: String {
        "\(daysSummary), \(hoursSummary)"
    }

    var daysSummary: String {
        let days = Self.mondayFirst.filter(weekdays.contains)
        switch days.count {
        case 0: return "nessun giorno"
        case 7: return "tutti i giorni"
        default: break
        }
        // Tre o più giorni consecutivi diventano un intervallo ("lun–ven").
        let positions = days.compactMap { Self.mondayFirst.firstIndex(of: $0) }
        let isRun = positions[positions.count - 1] - positions[0] == positions.count - 1
        if isRun, days.count >= 3 {
            return "\(Self.shortName(of: days[0]))–\(Self.shortName(of: days[days.count - 1]))"
        }
        return days.map { Self.shortName(of: $0) }.joined(separator: ", ")
    }

    var hoursSummary: String {
        if startMinute == endMinute { return "tutto il giorno" }
        return "\(Self.timeString(startMinute))–\(Self.timeString(endMinute))"
    }
}
