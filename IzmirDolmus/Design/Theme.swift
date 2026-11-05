import DolmusCore
import SwiftUI
import UIKit

/// Uygulamanın tasarım token'ları. Renkler dark mode'a ve yüksek kontrasta
/// kendiliğinden uyar: ya sistemin semantic renkleri ya da Assets'teki
/// açık/koyu değerli renkler kullanılır.
enum Theme {
    /// Köşe yarıçapları (Flutter'daki `AppTheme.r8/r14/r20`).
    enum Radius {
        /// Chip, rozet.
        static let chip: CGFloat = 8
        /// Kart, alan, button.
        static let card: CGFloat = 14
        /// Yüzen yüzey, sheet.
        static let sheet: CGFloat = 20
    }

    /// Navigation bar başlıklarını Figtree yapar. SwiftUI'ın `NavigationStack`'i
    /// altta `UINavigationBar` kullandığı için UIKit'in appearance proxy'si
    /// burada da geçerli. Punto açılıştaki Dynamic Type boyutuna göre ayarlanır.
    /// Scene kurulduktan sonra çağrılmalı (bkz. `RootView`).
    static func applyNavigationBarFonts() {
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: scaledFont("Figtree-ExtraBold", size: 34, style: .largeTitle)]
        appearance.titleTextAttributes = [.font: scaledFont("Figtree-Bold", size: 17, style: .headline)]
    }

    private static func scaledFont(_ name: String, size: CGFloat, style: UIFont.TextStyle) -> UIFont {
        let font = UIFont(name: name, size: size) ?? .preferredFont(forTextStyle: style)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
    }
}

extension Color {
    /// Sayfa zemini.
    static let canvas = Color(uiColor: .systemGroupedBackground)
    /// Kart ve panel yüzeyi.
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)

    /// Ücrete göre renk (Flutter'daki `AppTheme.feeColor` eşikleri): 55 ₺'ye
    /// kadar yeşil, 90'a kadar marka mavisi, 140'a kadar turuncu, üstü kırmızı.
    static func fee(_ fee: Int?) -> Color {
        switch FeeTier(fee) {
        case .unknown: .textSecondary
        case .low: .feeLow
        case .standard: .accent
        case .high: .feeHigh
        case .top: .feeTop
        }
    }
}

extension Font {
    /// Figtree'nin uygulamada kullanılan kalınlıkları.
    enum FigtreeWeight {
        case regular, medium, semibold, bold, extraBold

        fileprivate var fontName: String {
            switch self {
            case .regular: "Figtree-Regular"
            case .medium: "Figtree-Medium"
            case .semibold: "Figtree-SemiBold"
            case .bold: "Figtree-Bold"
            case .extraBold: "Figtree-ExtraBold"
            }
        }
    }

    /// Figtree; sistemin text style'ından 2 punto büyük başlar ve Dynamic Type ile
    /// onunla birlikte büyür.
    static func figtree(_ style: Font.TextStyle, weight: FigtreeWeight = .regular) -> Font {
        .custom(weight.fontName, size: style.baseSize, relativeTo: style)
    }
}

extension Font.TextStyle {
    /// Varsayılan (Large) yazı boyutundaki punto: sistemin değerinin 2 fazlası. Figtree
    /// aynı puntoda SF'ten küçük görünüyor; test kullanıcısı yazıları ufak buldu (2026-11-05).
    fileprivate var baseSize: CGFloat {
        let system: CGFloat = switch self {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
        return system + 2
    }
}
