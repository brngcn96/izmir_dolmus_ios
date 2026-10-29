/// Ücretin renk sınıfı (Flutter'daki `AppTheme.feeColor` eşikleri): 55 ₺'ye
/// kadar düşük, 90'a kadar olağan, 140'a kadar yüksek, üstü en yüksek. Uygulama
/// ve widget'lar her sınıfı kendi renk kataloğundaki renge çevirir.
public enum FeeTier: Sendable, Equatable {
    case unknown
    case low
    case standard
    case high
    case top

    public init(_ fee: Int?) {
        guard let fee else {
            self = .unknown
            return
        }
        self = switch fee {
        case ...55: .low
        case ...90: .standard
        case ...140: .high
        default: .top
        }
    }
}
