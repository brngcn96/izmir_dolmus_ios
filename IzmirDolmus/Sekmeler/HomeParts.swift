import DolmusCore
import MapKit
import SwiftUI

/// Başlık ve sağ üstte hava durumu (gelene kadar yalnızca yer adı).
struct HomeHeader: View {
    let weather: WeatherInfo?
    let district: String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Hava durumu başlığın ilk satırının yanında ("Nereye" kısa, çakışmaz);
        // büyük yazı boyutlarında başlığın üstünde.
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                weatherLabel
                title
            }
        } else {
            title
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    weatherLabel
                        .frame(maxWidth: 220, alignment: .trailing)
                        .padding(.top, 6)
                }
        }
    }

    private var title: some View {
        Text("Nereye\ngitmek istiyorsun?")
            .font(.figtree(.title, weight: .extraBold))
            .kerning(-0.6)
            .accessibilityAddTraits(.isHeader)
    }

    private var weatherLabel: some View {
        HStack(spacing: 6) {
            if let weather {
                Image(systemName: weather.look.symbol)
                    .symbolRenderingMode(.multicolor)
                Text(weather.temperatureLabel)
                    .font(.figtree(.headline, weight: .extraBold))
                    .monospacedDigit()
                Text("\(district) · \(weather.look.title)")
                    .font(.figtree(.footnote, weight: .medium))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            } else {
                Text(district)
                    .font(.figtree(.footnote, weight: .semibold))
                    .foregroundStyle(.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Arama alanı gibi görünür; dokununca "Nereden → Nereye" açılır.
struct SearchEntry: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Konum veya adres ara")
                    .font(.figtree(.subheadline, weight: .medium))
                    .foregroundStyle(.textSecondary)
                Spacer()
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surface, in: .rect(cornerRadius: Theme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Color(uiColor: .separator).opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Yol tarifi: konum veya adres ara")
    }
}

/// Ev · İş · Önemli Noktalar çipi. Ayarlanmamışsa soluk ve "+" işaretli.
struct ShortcutChip: View {
    let title: String
    let systemImage: String
    let isSet: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                Text(title)
                    .font(.figtree(.footnote, weight: .semibold))
                if !isSet {
                    Image(systemName: "plus")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(isSet ? Color.accent : Color.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSet ? Color.brandSoft : Color.surface, in: .rect(cornerRadius: Theme.Radius.chip))
            .overlay {
                if !isSet {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip)
                        .stroke(Color(uiColor: .separator).opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(isSet ? "Yol tarifi" : "Adres ekle")
    }
}

/// "İzmir'deki Etkinlikler" girişi.
struct EventsEntry: View {
    let summary: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "ticket")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.accent, in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text("İzmir’deki Etkinlikler")
                    .font(.figtree(.subheadline, weight: .extraBold))
                    .foregroundStyle(Color.primary)
                Text(summary)
                    .font(.figtree(.footnote))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.brandSoft, in: .rect(cornerRadius: 16))
        .contentShape(.rect(cornerRadius: 16))
    }
}

// MARK: - Yakındaki hatlar

/// "Yakındaki Dolmuş Hatları": konumun çevresi küçük bir haritada ve altında
/// hatların listesi. Dokununca konum Harita sekmesinde açılır.
struct NearbySection: View {
    let model: HomeModel
    let onShow: (PlacePoint) -> Void
    let onRetry: () -> Void

    /// Hatların çizgi renkleri, liste sırasıyla (Flutter'daki `_colors`).
    static let colors: [Color] = [
        .accent, Color(hex: 0xB42318), Color(hex: 0x16794C), Color(hex: 0xB54708), Color(hex: 0x6941C6),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Yakındaki Dolmuş Hatları")
                    .font(.figtree(.title3, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                // Dokunma alanı 44 pt; negatif boşluk başlık satırını büyütmesin diye.
                if let surroundings = model.surroundings {
                    Button {
                        onShow(surroundings.place)
                    } label: {
                        Text("Tümünü gör")
                            .tapTarget()
                    }
                    .font(.figtree(.subheadline, weight: .semibold))
                    .padding(.vertical, -10)
                } else if case .failed = model.phase {
                    Button(action: onRetry) {
                        Image(systemName: "arrow.clockwise")
                            .tapTarget()
                    }
                    .foregroundStyle(.textSecondary)
                    .accessibilityLabel("Yenile")
                    .padding(.vertical, -10)
                }
            }
            VStack(spacing: 0) {
                map
                if let surroundings = model.surroundings, !surroundings.nearby.isEmpty {
                    ForEach(Array(surroundings.nearby.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider().padding(.leading, 26)
                        }
                        Button {
                            onShow(surroundings.place)
                        } label: {
                            NearbyHatRow(item: item, color: Self.colors[index % Self.colors.count])
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.spokenLabel)
                    }
                }
            }
            .background(Color.surface)
            .clipShape(.rect(cornerRadius: Theme.Radius.card))
        }
    }

    @ViewBuilder
    private var map: some View {
        switch model.phase {
        case .idle, .locating:
            ProgressView()
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(Color.brandSoft)
        case .failed(let error):
            // Büyük yazı boyutlarında açıklama ve düğme sığsın diye yükseklik serbest.
            LocationUnavailable(error: error, onRetry: onRetry)
                .frame(minHeight: 190)
        case .located(let surroundings):
            let miniMap = NearbyMiniMap(surroundings: surroundings)
            miniMap
                .frame(height: 190)
                .contentShape(.rect)
                .onTapGesture {
                    onShow(surroundings.place)
                }
                .accessibilityElement()
                .accessibilityLabel("Yakındaki hatların haritası")
                .accessibilityValue(miniMap.summary)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    onShow(surroundings.place)
                }
        }
    }
}

/// Gezinmeyen küçük harita: konum, çevresinden geçen hatlar ve altta özet.
private struct NearbyMiniMap: View {
    let surroundings: HomeModel.Surroundings

    var body: some View {
        // ~2,6 km yükseklik: Flutter'daki 13,2 zoom'a yakın.
        let region = MKCoordinateRegion(
            center: surroundings.here.clCoordinate,
            latitudinalMeters: 2_600,
            longitudinalMeters: 2_600
        )
        Map(initialPosition: .region(region), interactionModes: []) {
            ForEach(Array(surroundings.lines.enumerated()), id: \.offset) { index, line in
                if line.count >= 2 {
                    MapPolyline(coordinates: line.map(\.clCoordinate))
                        .stroke(NearbySection.colors[index % NearbySection.colors.count].opacity(0.85), lineWidth: 4)
                }
            }
            Annotation("", coordinate: surroundings.here.clCoordinate) {
                Circle()
                    .fill(Color.accent)
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .overlay(alignment: .bottomLeading) {
            Text(summary)
                .font(.figtree(.caption, weight: .semibold))
                .lineLimit(2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: .rect(cornerRadius: 8))
                .padding(8)
        }
    }

    var summary: String {
        surroundings.nearby.isEmpty
            ? "Yakında dolmuş hattı yok"
            : "\(surroundings.label) · \(surroundings.nearby.count) hat"
    }
}

/// Konum alınamadıysa: açıklama ve yeniden deneme (izin yoksa Ayarlar'a gider).
private struct LocationUnavailable: View {
    let error: LocationError
    let onRetry: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash")
                .font(.title)
                .foregroundStyle(.textSecondary)
            Text(error.homeMessage)
                .font(.figtree(.footnote))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            if error == .denied {
                // İzin bir kez reddedilince sistem bir daha sormaz.
                Button("Ayarlar'ı aç", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.primary)
            } else {
                Button("Konumumu Kullan", systemImage: "location.fill", action: onRetry)
                    .buttonStyle(.primary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandSoft)
    }
}

/// Yakın hat satırı: renk şeridi (haritadaki çizgiyle aynı), ad, uzaklık, ücret.
private struct NearbyHatRow: View {
    let item: NearbyHat
    let color: Color

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Erişilebilirlik yazı boyutlarında ad, uzaklık ve ücret yan yana sığmaz.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(spacing: 10))

        HStack(spacing: 10) {
            Capsule()
                .fill(color)
                .frame(width: 4, height: 26)
            layout {
                Text(item.hat.name)
                    .font(.figtree(.subheadline, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.distanceLabel)
                    .font(.figtree(.caption, weight: .medium))
                    .foregroundStyle(.textSecondary)
                Text(item.hat.feeLabel)
                    .font(.figtree(.subheadline, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.fee(item.hat.feeMin))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }
}

// MARK: - Son aramalar

/// En son aranan yerler: dokununca haritada, ok düğmesiyle oraya yol tarifi.
struct RecentsSection: View {
    let places: [PlacePoint]
    let onShow: (PlacePoint) -> Void
    let onDirections: (PlacePoint) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Son Aramalar")
                    .font(.figtree(.title3, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onClear) {
                    Text("Temizle")
                        .tapTarget()
                }
                .font(.figtree(.subheadline, weight: .semibold))
                .padding(.vertical, -10)
            }
            VStack(spacing: 0) {
                ForEach(Array(places.enumerated()), id: \.element) { index, place in
                    if index > 0 {
                        Divider().padding(.leading, 44)
                    }
                    HStack(spacing: 12) {
                        Button {
                            onShow(place)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.tertiary)
                                Text(place.label)
                                    .font(.figtree(.subheadline, weight: .bold))
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        Button {
                            onDirections(place)
                        } label: {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.title3)
                                .tapTarget()
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("\(place.label) için yol tarifi")
                        .padding(.vertical, -8)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
            }
            .background(Color.surface, in: .rect(cornerRadius: Theme.Radius.card))
        }
    }
}
