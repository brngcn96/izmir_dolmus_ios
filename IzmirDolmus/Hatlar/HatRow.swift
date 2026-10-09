import DolmusCore
import SwiftUI

/// Hat listesindeki satır: hat adı, geçtiği ilçeler ve ücret aralığı.
struct HatRow: View {
    let hat: DolmusHat

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(hat.name)
                    .font(.headline)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            Text(hat.feeLabel)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.tint)
        }
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
}
