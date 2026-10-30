import Foundation

/// Pausa pranzo: fascia giornaliera in cui KeepMeOn non interviene (es. 13:00–14:00).
///
/// - Vale tutti i giorni.
/// - L'inizio è incluso, la fine esclusa (13:00–14:00 vale fino alle 13:59).
/// - Se la fine viene prima dell'inizio la pausa scavalca la mezzanotte.
/// - Se inizio e fine coincidono la pausa è vuota.
public struct LunchBreak: Equatable, Sendable {
    /// Minuti dalla mezzanotte, 0…1439.
    public var startMinute: Int
    public var endMinute: Int

    /// Predefinita: 13:00–14:00.
    public static let standard = LunchBreak(startMinute: 13 * 60, endMinute: 14 * 60)

    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = min(max(startMinute, 0), WorkHours.minutesPerDay - 1)
        self.endMinute = min(max(endMinute, 0), WorkHours.minutesPerDay - 1)
    }

    /// Vero se `date` cade nella pausa.
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = parts.hour, let minute = parts.minute else { return false }
        let now = hour * 60 + minute

        if startMinute <= endMinute {
            return (startMinute..<endMinute).contains(now)
        }
        return now >= startMinute || now < endMinute
    }

    /// Descrizione breve, es. "13:00–14:00".
    public var summary: String {
        "\(WorkHours.timeString(startMinute))–\(WorkHours.timeString(endMinute))"
    }
}
