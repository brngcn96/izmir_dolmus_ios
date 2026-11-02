import Foundation

/// Ekrandaki kısa etiketlerin VoiceOver okunuşu: "~", "–" ve "₺" gibi işaretlerin
/// nasıl okunacağı cihaza bırakılmaz.
extension String {
    /// "40–65 ₺" → "40 ile 65 lira arası"; "50 ₺" → "50 lira"; "Ücret ?" ya da
    /// "—" → "ücret bilinmiyor".
    public var spokenFee: String {
        guard hasSuffix("₺") else { return "ücret bilinmiyor" }
        let amount = dropLast().trimmingCharacters(in: .whitespaces)
        let parts = amount.split(separator: "–")
        return parts.count == 2 ? "\(parts[0]) ile \(parts[1]) lira arası" : "\(amount) lira"
    }

    /// "~350 m" → "yaklaşık 350 metre"; "1,2 km" → "1,2 kilometre".
    public var spokenDistance: String {
        let isApproximate = hasPrefix("~")
        let text = isApproximate ? String(dropFirst()) : self
        let spoken = if text.hasSuffix(" km") {
            "\(text.dropLast(3)) kilometre"
        } else if text.hasSuffix(" m") {
            "\(text.dropLast(2)) metre"
        } else {
            text
        }
        return isApproximate ? "yaklaşık \(spoken)" : spoken
    }
}
