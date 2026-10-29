import DolmusCore
import SwiftUI

extension Color {
    /// Ücretin rengi; eşikler `FeeTier`'da, renkler bu eklentinin kataloğunda
    /// (uygulamanınkilerin kopyası).
    static func fee(_ fee: Int?) -> Color {
        switch FeeTier(fee) {
        case .unknown: .secondary
        case .low: .feeLow
        case .standard: .accentColor
        case .high: .feeHigh
        case .top: .feeTop
        }
    }
}
