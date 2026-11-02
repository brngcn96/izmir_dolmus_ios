import DolmusCore
import SwiftUI

/// Nokta türünün haritadaki simgesi ve rengi (Flutter'daki `_lmIcons`, `_lmColors`).
struct PoiStyle {
    let symbol: String
    let color: Color
    /// Kalabalık türler: simge yok, yalnızca ad (harita sade kalsın).
    let isIconless: Bool

    init(type: String) {
        let (symbol, hex): (String, UInt32) = switch type {
        case "metro": ("tram.fill.tunnel", 0xC62828)
        case "izban", "istasyon": ("train.side.front.car", 0x00695C)
        case "tramvay": ("tram.fill", 0x6A1B9A)
        case "iskele": ("ferry.fill", 0x0277BD)
        case "otogar": ("bus.fill", 0x1565C0)
        case "universite": ("graduationcap.fill", 0x283593)
        case "hastane": ("cross.case.fill", 0xD32F2F)
        case "eczane": ("pills.fill", 0x2E7D32)
        case "avm": ("bag.fill", 0xAD1457)
        case "stadyum": ("sportscourt.fill", 0x2E7D32)
        case "belediye": ("building.columns.fill", 0x607D8B)
        case "adliye": ("scalemass.fill", 0x607D8B)
        case "pazar": ("basket.fill", 0x607D8B)
        case "okul": ("book.fill", 0x00695C)
        case "durak": ("bus", 0x455A64)
        case "poi": ("storefront.fill", 0x6A4C93)
        case "muze": ("building.columns", 0x5E35B1)
        case "turistik": ("camera.fill", 0x8D6E63)
        case "park": ("tree.fill", 0x388E3C)
        case "kultur": ("theatermasks.fill", 0xEF6C00)
        case "spor": ("figure.run", 0x00838F)
        case "otel": ("bed.double.fill", 0xF9A825)
        case "dugun": ("sparkles", 0xD81B60)
        case "nikah": ("heart.fill", 0xC2185B)
        case "magaza": ("storefront", 0x3949AB)
        case "kafe": ("cup.and.saucer.fill", 0x6D4C41)
        case "restoran": ("fork.knife", 0xE64A19)
        case "bar": ("wineglass.fill", 0x8E24AA)
        case "pastane": ("birthday.cake.fill", 0xEC407A)
        default: ("mappin", 0x607D8B)
        }
        self.symbol = symbol
        self.color = Color(hex: hex)
        isIconless = ["kafe", "restoran", "bar", "pastane", "otel", "dugun", "nikah", "magaza"].contains(type)
    }
}

/// Haritadaki bir nokta: renkli simge ve (yeterince yakınsa) adı.
struct PoiMarker: View {
    let poi: MapPoi
    let isLabeled: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if poi.type == "mahalle" {
            // Semt/mahalle: pinsiz, yön bulmak için sade etiket.
            Text(name.uppercased(with: .turkish))
                .font(.figtree(.caption2, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? Color(hex: 0xB0BEC5) : Color(hex: 0x546E7A))
                .halo()
        } else {
            let style = PoiStyle(type: poi.type)
            VStack(spacing: 1) {
                if !style.isIconless {
                    Image(systemName: style.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(style.color)
                        .frame(width: 22, height: 22)
                        .background(.white, in: .circle)
                        .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                }
                if isLabeled || style.isIconless {
                    // Koyu haritada türün koyu rengi okunmuyor: açılır.
                    Text(name)
                        .font(.figtree(.caption2, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? style.color.mix(with: .white, by: 0.45) : style.color)
                        .lineLimit(1)
                        .frame(maxWidth: 120)
                        .halo()
                }
            }
        }
    }

    /// "Bornova Metro · Bornova" → "Bornova Metro".
    var name: String {
        poi.label.split(separator: "·").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? poi.label
    }
}

private extension View {
    /// Metnin her zeminde okunması için dış hat (bulanıklıksız, ucuz): açık
    /// haritada beyaz, koyu haritada siyah.
    func halo() -> some View {
        modifier(Halo())
    }
}

private struct Halo: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let color: Color = colorScheme == .dark ? .black : .white
        content
            .shadow(color: color, radius: 0, x: 1, y: 1)
            .shadow(color: color, radius: 0, x: -1, y: -1)
    }
}

/// Seçilen noktanın iğnesi.
struct ProbePin: View {
    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 30))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.accent)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}

/// Tek hat görünümünün alt bandı: ad, ücret, binme yeri, güzergah çipleri.
struct RouteBanner: View {
    let model: MapModel
    let hat: DolmusHat
    let onDetail: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "bus.fill")
                    .foregroundStyle(.accent)
                    .accessibilityHidden(true)
                Text(hat.name)
                    .font(.figtree(.headline, weight: .bold))
                    .lineLimit(3)
                Spacer(minLength: 4)
                Text(hat.feeLabel)
                    .font(.figtree(.subheadline, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.fee(hat.feeMin))
                    .accessibilityLabel(hat.feeLabel.spokenFee)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.textSecondary)
                        .tapTarget()
                }
                .accessibilityLabel("Kapat")
                .padding(-8)
            }
            if let meters = model.boardMeters, let probe = model.probe {
                Label("Bu hatta binmek için \(NearbyHat.distanceLabel(meters)) yürü (\(probe.label))", systemImage: "figure.walk")
                    .font(.figtree(.subheadline))
                    .accessibilityLabel("Bu hatta binmek için \(NearbyHat.distanceLabel(meters).spokenDistance) yürü (\(probe.label))")
            }
            if let geom = model.selectedGeom {
                Label("Resmi İBB güzergahı (UKOME): \(geom.ad)", systemImage: "info.circle")
                    .font(.figtree(.footnote))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
            } else {
                Label("Bu hat için güzergah verisi yok.", systemImage: "info.circle")
                    .font(.figtree(.footnote))
                    .foregroundStyle(.textSecondary)
            }
            if model.geoms.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        // Dizinin kendisi üzerinden: "geri"de güzergahlar boşalırken
                        // bant bir kez daha çizilebiliyor; indeksle okumak çöker.
                        ForEach(Array(model.geoms.enumerated()), id: \.offset) { index, geom in
                            let isSelected = index == model.geomIndex
                            Button {
                                model.selectGeom(index)
                            } label: {
                                Text(model.label(for: geom))
                                    .font(.figtree(.footnote, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(isSelected ? Color.white : Color.accent)
                                    .background(isSelected ? Color.accent : Color.brandSoft, in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            Button(action: onDetail) {
                Label("Hat Detayları, Ücretler ve Geri Bildirim", systemImage: "list.bullet")
                    .font(.figtree(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.sheet))
        .padding(.horizontal, 12)
    }
}

/// Nokta seçiliyken altta: yakın hat listesi düğmesi ya da "yakında hat yok".
struct ProbePanel: View {
    let model: MapModel
    let onShowNearest: (String) -> Void
    let onDirections: (PlacePoint) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if model.nearby.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    model.nearest == nil ? "Bu bölgede dolmuş hattı yok" : "Yakında (800 m) dolmuş yok",
                    systemImage: "exclamationmark.circle"
                )
                .font(.figtree(.headline, weight: .bold))
                if let nearest = model.nearest {
                    HStack {
                        Text("En yakını: \(nearest.hat.name) · \(nearest.distanceLabel)")
                            .font(.figtree(.subheadline))
                            .foregroundStyle(.textSecondary)
                        Spacer()
                        Button("Göster") { onShowNearest(nearest.hat.id) }
                            .font(.figtree(.subheadline, weight: .bold))
                    }
                } else {
                    Text("Buraya yürüme mesafesinde hat bulunamadı.")
                        .font(.figtree(.subheadline))
                        .foregroundStyle(.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.sheet))
            .padding(.horizontal, 12)
        } else {
            GlassEffectContainer(spacing: 10) {
                // Büyük yazı boyutlarında iki düğme yan yana sığmaz.
                let layout = typeSize >= .xxLarge ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                layout {
                    Button {
                        model.isShowingNearbyList = true
                    } label: {
                        Label(
                            model.previewIDs.isEmpty ? "Hat listesi (\(model.nearby.count))" : "Hat listesi · \(model.previewIDs.count) çizili",
                            systemImage: "bus"
                        )
                        .font(.figtree(.headline, weight: .semibold))
                        .padding(.horizontal, 18)
                        .frame(minHeight: 50)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    if let probe = model.probe {
                        Button {
                            onDirections(probe)
                        } label: {
                            Label("Yol tarifi", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.figtree(.headline, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .frame(minHeight: 50)
                        }
                        .glassEffect(.regular.tint(.accent).interactive(), in: .capsule)
                    }
                }
            }
        }
    }
}

/// Önizleme çizgisine dokununca: o çizgideki hat(lar).
struct TappedLinesCard: View {
    let model: MapModel
    let hats: [DolmusHat]
    let onOpen: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(hats.count == 1 ? "Bu çizgi:" : "Bu çizgide \(hats.count) hat üst üste:")
                    .font(.figtree(.footnote, weight: .semibold))
                    .foregroundStyle(.textSecondary)
                Spacer()
                Button {
                    model.dismissTappedHats()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.textSecondary)
                        .tapTarget()
                }
                .accessibilityLabel("Kapat")
                .padding(-12)
            }
            ForEach(hats) { hat in
                Button {
                    onOpen(hat.id)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(model.previewColor(for: hat.id))
                            .frame(width: 10, height: 10)
                        Text(hat.name)
                            .font(.figtree(.subheadline, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                        Spacer()
                        Text(hat.feeLabel)
                            .font(.figtree(.footnote, weight: .bold))
                            .foregroundStyle(.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(hat.name), \(hat.feeLabel.spokenFee)")
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.card))
        .padding(.horizontal, 12)
    }
}

/// Seçilen noktaya yakın hatlar: dokununca çizgi açılır/kapanır, ok ile hat açılır.
struct NearbyListSheet: View {
    let model: MapModel
    let onOpen: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.nearby) { item in
                    let isOn = model.previewIDs.contains(item.hat.id)
                    HStack(spacing: 12) {
                        Button {
                            model.togglePreview(item.hat.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isOn ? model.previewColor(for: item.hat.id) : Color.textSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.hat.name)
                                        .font(.figtree(.subheadline, weight: .bold))
                                        .foregroundStyle(Color.primary)
                                    // `Color.textSecondary`: `.secondary` button içinde tint'ten
                                    // türüyor, koyu modda okunmuyordu.
                                    Text(item.distanceLabel)
                                        .font(.figtree(.caption))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                Spacer(minLength: 4)
                                Text(item.hat.feeLabel)
                                    .font(.figtree(.footnote, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.fee(item.hat.feeMin))
                            }
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(item.spokenLabel)
                        .accessibilityHint("Çizgiyi haritada gösterir ya da kaldırır")
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                        Button {
                            onOpen(item.hat.id)
                        } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.accent)
                                .tapTarget()
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("\(item.hat.name) hattını aç")
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Yakındaki hatlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tümü") { model.previewAll() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Temizle") { model.clearPreviews() }
                        .disabled(model.previewIDs.isEmpty)
                }
            }
        }
    }
}

/// Haritanın üstünde kısa bir bilgi (ör. rota bulunamadı); dokununca kapanır.
struct MessageCard: View {
    let text: String
    let onClose: () -> Void

    var body: some View {
        Button(action: onClose) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.accent)
                Text(text)
                    .font(.figtree(.subheadline))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.card))
        .padding(.horizontal, 12)
    }
}
