import Foundation

extension EventItem {
    /// Kart için kısa tarih: "Cum 16 Eki · 20:30". Saat 00:00 ise saat yazılmaz.
    public var shortDateLabel: String? {
        start.map { Self.label(for: $0, days: Self.shortDays, months: Self.shortMonths, separator: " ") }
    }

    /// Detay için uzun tarih: "Cuma, 16 Ekim · 20:30".
    public var longDateLabel: String? {
        start.map { Self.label(for: $0, days: Self.longDays, months: Self.longMonths, separator: ", ") }
    }

    /// Detaydaki tür satırı: "Konser · Rock". İBB'nin türleri zaten Türkçe
    /// (SERGİ…), olduğu gibi gösterilir.
    public var categoryLabel: String? {
        guard let category else { return nil }
        let name = switch kind {
        case .music, .stage: kind.title
        case .other: ["sport", "spor"].contains(where: trNorm(category).dartContains) ? "Spor" : category
        }
        return genre.map { "\(name) · \($0)" } ?? name
    }

    /// "350–900 TL", "450 TL"; fiyat bilinmiyorsa `nil`. Yalnızca bilgi, satış yok.
    public var priceLabel: String? {
        guard priceMin != nil || priceMax != nil else { return nil }
        let currency = currency == nil || currency == "TRY" ? "TL" : currency!
        func number(_ value: Double) -> String {
            value == value.rounded() ? String(Int(value)) : String(value)
        }
        if let low = priceMin, let high = priceMax, low != high {
            return "\(number(low))–\(number(high)) \(currency)"
        }
        return "\(number(priceMax ?? priceMin!)) \(currency)"
    }

    /// "Kaynak: …" satırı.
    public var sourceName: String {
        source == "ibb" ? "İzmir Büyükşehir Belediyesi" : "Ticketmaster (Biletix)"
    }

    // Takvimin `weekday`'i Pazar = 1 ile başlar.
    private static let shortDays = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"]
    private static let longDays = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"]
    private static let shortMonths = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]
    private static let longMonths = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

    private static func label(for date: Date, days: [String], months: [String], separator: String) -> String {
        let parts = Calendar.istanbul.dateComponents([.weekday, .day, .month, .hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let time = hour != 0 || minute != 0 ? String(format: " · %02d:%02d", hour, minute) : ""
        return "\(days[(parts.weekday ?? 1) - 1])\(separator)\(parts.day ?? 0) \(months[(parts.month ?? 1) - 1])\(time)"
    }
}
