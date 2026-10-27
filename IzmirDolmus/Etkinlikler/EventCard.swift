import DolmusCore
import SwiftUI

/// Etkinlik listesindeki kart: afiş, tarih, başlık ve mekan.
struct EventCard: View {
    let event: EventItem

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Erişilebilirlik yazı boyutlarında metin afişin yanına sığmaz: afiş
        // üstte, metin tam genişlikte.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))

        layout {
            poster
            VStack(alignment: .leading, spacing: 3) {
                if let date = event.shortDateLabel {
                    Text(date)
                        .font(.figtree(.caption, weight: .bold))
                        .foregroundStyle(.accent)
                }
                Text(event.title)
                    .font(.figtree(.headline, weight: .bold))
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                if let venue = event.venue {
                    Text(venue)
                        .font(.figtree(.subheadline))
                        .foregroundStyle(.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// Afiş; yüklenirken dönen gösterge, yoksa ya da yüklenemezse türün simgesi.
    private var poster: some View {
        AsyncImage(url: event.imageURL) { phase in
            switch phase {
            case .success(let image):
                // `resizable` görüntünün kendisine uygulanır, AsyncImage'a değil.
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                symbol
            case .empty:
                // URL yokken de `.empty` gelir: o zaman simge, varsa yükleniyor.
                if event.imageURL == nil {
                    symbol
                } else {
                    ProgressView()
                }
            @unknown default:
                symbol
            }
        }
        .frame(width: 96, height: 72)
        .background(Color.brandSoft)
        .clipShape(.rect(cornerRadius: Theme.Radius.chip))
        .accessibilityHidden(true)
    }

    private var symbol: some View {
        Image(systemName: event.kind.symbol)
            .font(.title2)
            .foregroundStyle(.accent)
    }
}
