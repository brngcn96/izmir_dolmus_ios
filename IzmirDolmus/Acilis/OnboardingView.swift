import CoreLocation
import SwiftUI

/// İlk açılış tanıtımı: üç sayfa; sonuncusunda konum izni bağlamıyla birlikte
/// istenir (Flutter'daki `OnboardingScreen`). Veri bu sırada arka planda yüklenir.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var location = LocationProvider()
    @State private var locationState = LocationState.notAsked

    private static let lastPage = 2

    enum LocationState {
        case notAsked
        case asking
        case granted
        case denied
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Atla", action: onFinish)
                    .font(.figtree(.subheadline, weight: .semibold))
                    .foregroundStyle(.textSecondary)
                    .opacity(page < Self.lastPage ? 1 : 0)
                    .disabled(page == Self.lastPage)
                    .accessibilityHidden(page == Self.lastPage)
                    .animation(.easeOut(duration: 0.2), value: page)
            }
            .frame(height: 48)
            .padding(.horizontal, 20)

            TabView(selection: $page) {
                welcomePage.tag(0)
                journeyPage.tag(1)
                mapPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(count: Self.lastPage + 1, current: page)
                .padding(.bottom, 16)

            Button {
                if page < Self.lastPage {
                    withAnimation(.easeOut(duration: 0.32)) { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < Self.lastPage ? "İleri" : "Başla")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color.canvas)
    }

    // MARK: Sayfalar

    private var welcomePage: some View {
        OnboardingPage(title: "İzmir Dolmuş") {
            // Motor çalışıyormuş gibi hafif bir sallanma; hareket azaltılmışsa durur.
            PhaseAnimator(reduceMotion ? [0.0] : [0.0, -3.0]) { lift in
                Image(.dolmus)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
                    .offset(y: lift)
            } animation: { _ in
                .easeInOut(duration: 0.45)
            }
            .frame(height: 140)
            .accessibilityHidden(true)
        } content: {
            BodyText("İzmir'in tüm dolmuş hatları, güzergahları ve kapıdan kapıya yol tarifi — çevrimdışı çalışır.")
        }
    }

    private var journeyPage: some View {
        OnboardingPage(title: "Nereden → Nereye") {
            IconBadge(systemImage: "arrow.triangle.branch")
        } content: {
            BodyText("İki nokta seç; en iyi rotayı önerelim — aktarma, ücret ve tahmini süreyle.")
            Label("Süreler tahminidir; sefer saati/sıklık verisi yoktur.", systemImage: "info.circle")
                .font(.figtree(.footnote, weight: .medium))
                .foregroundStyle(.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.brandSoft, in: .rect(cornerRadius: Theme.Radius.card))
                .padding(.top, 18)
        }
    }

    private var mapPage: some View {
        OnboardingPage(title: "Haritayı keşfet") {
            IconBadge(systemImage: "map.fill")
        } content: {
            BodyText("Haritada bir yere uzun bas → oradan geçen hatları gör. Bir hatta dokun → resmi güzergah, ücret ve duraklar.")
            locationCard
                .padding(.top, 20)
        }
    }

    /// Konum izni, neden istendiği yazılı olarak.
    private var locationCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: locationState == .granted ? "checkmark.circle.fill" : "location.fill")
                    .font(.title3)
                    .foregroundStyle(locationState == .granted ? Color.feeLow : Color.accent)
                Text(locationText)
                    .font(.figtree(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if locationState != .granted {
                Button {
                    Task { await askLocation() }
                } label: {
                    Group {
                        if locationState == .asking {
                            ProgressView()
                        } else {
                            Text("Konumumu kullan")
                                .font(.figtree(.subheadline, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.chip)
                            .stroke(Color.accent)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.accent)
                .disabled(locationState == .asking)
                .accessibilityLabel("Konumumu kullan")
            }
        }
        .padding(16)
        .background(Color.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private var locationText: String {
        switch locationState {
        case .granted: "Konum izni verildi."
        case .denied: "Konum izni verilmedi; istersen Ayarlar'dan açabilirsin."
        case .notAsked, .asking: "Konumunu göster ve yakın hatları bul."
        }
    }

    /// İzin sorulur; verilirse konum da bir kez alınır (Anasayfa'ya hazır olur).
    private func askLocation() async {
        locationState = .asking
        do {
            _ = try await location.currentLocation()
            locationState = .granted
        } catch {
            // Konum gelmese de (ör. zaman aşımı) izin verilmiş olabilir.
            let status = CLLocationManager().authorizationStatus
            let isAuthorized = status == .authorizedWhenInUse || status == .authorizedAlways
            locationState = isAuthorized ? .granted : .denied
        }
    }
}

/// Bir tanıtım sayfası: görsel, başlık, açıklama.
private struct OnboardingPage<Visual: View, Content: View>: View {
    let title: String
    @ViewBuilder let visual: Visual
    @ViewBuilder let content: Content

    var body: some View {
        // Sığarsa dikeyde ortalı; büyük yazı boyutlarında kaydırılır.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    visual
                    Text(title)
                        .font(.figtree(.title2, weight: .extraBold))
                        .kerning(-0.4)
                        .multilineTextAlignment(.center)
                        .padding(.top, 32)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        content
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct BodyText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.figtree(.body, weight: .medium))
            .foregroundStyle(.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
    }
}

private struct IconBadge: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 56, weight: .semibold))
            .foregroundStyle(.accent)
            .frame(width: 132, height: 132)
            .background(Color.brandSoft, in: .circle)
            .accessibilityHidden(true)
    }
}

/// Sayfa noktaları: geçerli sayfa uzun.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accent : Color(uiColor: .systemGray4))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.easeOut(duration: 0.25), value: current)
        .accessibilityElement()
        .accessibilityLabel("Sayfa \(current + 1) / \(count)")
    }
}

#Preview {
    OnboardingView {}
}
