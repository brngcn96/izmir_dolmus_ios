import GoogleMobileAds
import SwiftUI
import UIKit

/// Bir sekmede banner reklamın yeri (bkz. `RouteStack`).
enum BannerPlacement {
    /// Sekmenin bütün ekranlarında.
    case always
    /// Bütün ekranlarında; kökte açık yüklenip kullanıcının daraltabildiği (collapsible)
    /// biçimde (Flutter'da Favoriler sekmesi), itilen ekranlarda normal.
    case collapsible
    /// Yalnızca köke itilen ekranlarda: Hatlar'ın kökünde arama alanı ve klavye var.
    case pushed
}

extension View {
    /// Ekranın altına, tab bar'ın üstüne banner reklam koyar. Ekranın kendi alt
    /// çubuğu (ör. hat detayındaki "Haritada göster") banner'ın üstünde kalır.
    @ViewBuilder
    func adBanner(_ isShown: Bool, isCollapsible: Bool = false) -> some View {
        if isShown {
            safeAreaInset(edge: .bottom, spacing: 0) {
                AdBanner(isCollapsible: isCollapsible)
            }
        } else {
            self
        }
    }
}

/// Sayfanın altındaki banner reklam (Flutter'daki `BannerAdWidget`). Yüklenene kadar yer
/// kaplamaz. Klavye açıkken gizlenir: klavyenin hemen üstüne çıkan reklam yanlışlıkla
/// dokunmaya açık.
struct AdBanner: View {
    var isCollapsible = false

    @Environment(AdsController.self) private var ads
    @State private var width: CGFloat?
    @State private var adHeight: CGFloat = 0
    @State private var isKeyboardVisible = false

    var body: some View {
        if ads.canRequestAds {
            ZStack {
                if let width {
                    BannerAdView(width: width, isCollapsible: isCollapsible, isHidden: isHidden) { height in
                        adHeight = height
                    }
                    .id(width)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: isHidden ? 0 : adHeight)
            .background(Color.canvas)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
        }
    }

    private var isHidden: Bool {
        isKeyboardVisible || adHeight == 0
    }
}

/// UIKit'teki `BannerView`'ın sarmalayıcısı. Boyut, Android'deki gibi standart sabit
/// (anchored) adaptive banner: tam genişlik, ~60 nokta. SDK 13 bunun yerine ~125 noktalık
/// "large" banner'ı öneriyor ve bu boyutu deprecated işaretledi (derlemede uyarı); büyük
/// banner tab bar'la birlikte ekranın dörtte birini kaplıyordu (kullanıcının kararı,
/// 2026-11-04). SDK'nın bir sonraki büyük sürümünde yeniden bakılmalı.
private struct BannerAdView: UIViewRepresentable {
    let width: CGFloat
    let isCollapsible: Bool
    let isHidden: Bool
    let onLoad: (CGFloat) -> Void

    func makeUIView(context: Context) -> BannerContainer {
        BannerContainer(
            size: portraitAnchoredAdaptiveBanner(width: width),
            unitID: isCollapsible ? AdUnit.collapsibleBanner : AdUnit.banner,
            isCollapsible: isCollapsible
        )
    }

    func updateUIView(_ container: BannerContainer, context: Context) {
        container.onLoad = onLoad
        // Gizliyken (yüklenmeden ya da klavye açıkken) yükseklik sıfır; reklam taşmasın.
        // Açıkken kırpılmaz: collapsible reklamın açık hali banner'ın üstüne taşar.
        container.clipsToBounds = isHidden
    }
}

/// Banner'ı taşıyan görünüm. Reklam pencereye girince istenir: tıklanınca açılacağı
/// view controller ve sahne o zaman bellidir.
private final class BannerContainer: UIView, BannerViewDelegate {
    var onLoad: ((CGFloat) -> Void)?

    private let banner: BannerView
    private let isCollapsible: Bool

    init(size: AdSize, unitID: String, isCollapsible: Bool) {
        banner = BannerView(adSize: size)
        self.isCollapsible = isCollapsible
        super.init(frame: .zero)
        banner.adUnitID = unitID
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(banner)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: topAnchor),
            banner.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) kullanılmıyor")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window, banner.rootViewController == nil else { return }
        banner.rootViewController = window.rootViewController
        let request = Request()
        request.scene = window.windowScene
        if isCollapsible {
            // Açık hali, alt kenarı daraltılmış banner'ın alt kenarına hizalı açılır.
            let extras = Extras()
            extras.additionalParameters = ["collapsible": "bottom"]
            request.register(extras)
        }
        banner.load(request)
    }

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        onLoad?(bannerView.adSize.size.height)
    }
}
