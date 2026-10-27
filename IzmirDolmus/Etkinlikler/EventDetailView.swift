import DolmusCore
import SwiftUI

/// `Route.event` hedefinin ekranı: kimlikten etkinliği bulup detayını gösterir.
struct EventDestinationView: View {
    let eventID: String

    @Environment(EventsStore.self) private var store

    var body: some View {
        if let event = store.event(id: eventID) {
            EventDetailView(event: event)
        } else {
            ContentUnavailableView("Etkinlik bulunamadı", systemImage: "calendar.badge.exclamationmark")
        }
    }
}

/// Etkinlik detayı: afiş, tarih, mekan, tür, fiyat, açıklama ve haritada gösterme.
struct EventDetailView: View {
    let event: EventItem

    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                banner
                Text(event.title)
                    .font(.figtree(.title2, weight: .extraBold))
                VStack(alignment: .leading, spacing: 10) {
                    if let date = event.longDateLabel {
                        info(date, systemImage: "calendar", isBold: true)
                    }
                    if let venue = event.venue {
                        info(venue, systemImage: "mappin.and.ellipse")
                    }
                    if let category = event.categoryLabel {
                        info(category, systemImage: "ticket")
                    }
                    if let price = event.priceLabel {
                        info(price, systemImage: "turkishlirasign.circle")
                    }
                }
                if let details = event.details {
                    Text(details)
                        .font(.figtree(.subheadline))
                        .foregroundStyle(.secondary)
                }
                if let coordinate = event.coordinate {
                    let venue = PlacePoint(label: event.venue ?? event.title, coordinate: coordinate)
                    Button {
                        router.planTrip(to: venue)
                    } label: {
                        Label("Yol tarifi", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary)
                    Button {
                        router.showOnMap(.place(venue))
                    } label: {
                        Label("Haritada göster", systemImage: "map")
                            .font(.figtree(.headline, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    Text("Bu etkinlik için konum bilgisi bulunmuyor.")
                        .font(.figtree(.footnote))
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.surface, in: .rect(cornerRadius: Theme.Radius.chip))
                }
                Text("Kaynak: \(event.sourceName)")
                    .font(.figtree(.caption))
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .background(Color.canvas)
        .navigationTitle("Etkinlik")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Afiş 16:9; yoksa ya da yüklenemezse türün simgesi.
    private var banner: some View {
        Color.brandSoft
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                AsyncImage(url: event.imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if phase.error != nil || event.imageURL == nil {
                        Image(systemName: event.kind.symbol)
                            .font(.largeTitle)
                            .foregroundStyle(.accent)
                    } else {
                        ProgressView()
                    }
                }
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.card))
            .accessibilityHidden(true)
    }

    private func info(_ text: String, systemImage: String, isBold: Bool = false) -> some View {
        Label {
            Text(text)
                .font(.figtree(.body, weight: isBold ? .bold : .regular))
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.accent)
        }
    }
}
