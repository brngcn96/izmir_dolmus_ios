import DolmusCore
import SwiftUI

/// Hat listesindeki satır: hat adı, geçtiği ilçeler ve ücret aralığı.
struct HatRow: View {
    let hat: DolmusHat
    /// Favori hatların adının yanında yıldız gösterilsin mi.
    var showsFavoriteMark = true

    @Environment(UserStore.self) private var user
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Erişilebilirlik yazı boyutlarında ad ile ücret yan yana sığmaz; alt alta dizilir.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))

        layout {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(hat.name)
                        .font(.figtree(.headline, weight: .bold))
                    if showsFavoriteMark && user.isFavorite(hat.id) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favori")
                    }
                }
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.figtree(.subheadline))
                        .foregroundStyle(.textSecondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(hat.feeLabel)
                .font(.figtree(.subheadline, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.fee(hat.feeMin))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    /// "Buca - Bornova, favori, Buca, Bornova, 4 ücret bölgesi, 40 ile 65 lira arası".
    private var spokenLabel: String {
        var parts = [hat.name]
        if showsFavoriteMark && user.isFavorite(hat.id) {
            parts.append("favori")
        }
        if !subtitle.isEmpty {
            parts.append(subtitle.replacing(" · ", with: ", ").replacing(" / ", with: ", "))
        }
        parts.append(hat.feeLabel.spokenFee)
        return parts.joined(separator: ", ")
    }

    /// "Bornova / Buca · 4 ücret bölgesi". Ücret satırı olmayan hatta yalnızca ilçe.
    private var subtitle: String {
        var parts: [String] = []
        if let ilce = hat.ilce, !ilce.isEmpty {
            parts.append(ilce)
        }
        if !hat.segments.isEmpty {
            parts.append("\(hat.segments.count) ücret bölgesi")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    List {
        HatRow(hat: DolmusHat(
            id: "M41",
            name: "GEDİZ - IŞIKKENT",
            segments: [
                DolmusRoute(
                    id: "M41_r1", groupID: "M41", groupName: "GEDİZ - IŞIKKENT", name: "GEDİZ-OTOGAR",
                    stops: ["GEDİZ", "OTOGAR"], stopsNorm: ["gediz", "otogar"], fee: 45, ilce: "Bornova / Buca"
                ),
                DolmusRoute(
                    id: "M41_r2", groupID: "M41", groupName: "GEDİZ - IŞIKKENT", name: "GEDİZ-IŞIKKENT",
                    stops: ["GEDİZ", "IŞIKKENT"], stopsNorm: ["gediz", "isikkent"], fee: 60, ilce: "Bornova / Buca"
                ),
            ]
        ))
        HatRow(hat: DolmusHat(id: "M19#manavkuyu", name: "Buca - Manavkuyu", segments: [], ilce: "Buca / Konak"))
    }
    .environment(UserStore(defaults: UserDefaults(suiteName: "preview")!))
}
