import Foundation

extension Calendar {
    /// Gün anahtarı ("2026-10-31"), takvimin saat diliminde. "Günde bir" kuralları
    /// (değerlendirme isteği, tam ekran reklamlar) son günü bununla saklar; biçim
    /// Flutter sürümündekiyle aynı.
    func dayKey(for date: Date) -> String {
        let parts = dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
