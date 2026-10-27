import DolmusCore
import SwiftUI

/// Etkinlikler: önbellekten anında açılır, liste bayatsa ağdan tazelenir;
/// aşağı çekince yeniden yüklenir.
struct EventsView: View {
    @Environment(EventsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        content
            .navigationTitle("Etkinlikler")
            // Başlık küçük ve arama alanı hep açık: navigation bar'ın yüksekliği
            // kaydırırken değişmez. Değişseydi altındaki `safeAreaBar` ile
            // birlikte liste tepeye varınca titriyordu.
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $store.filter.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Etkinlik ara")
            .safeAreaBar(edge: .top) {
                EventFilterBar()
            }
            // Görev ekranla yaşar: ekran kapanınca iptal edilir, yeniden
            // açılınca baştan başlar. İsteğin kendisi store'da; o yarıda kalmaz.
            .task {
                await store.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .idle, .loading:
            ProgressView("Etkinlikler yükleniyor…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let error):
            ContentUnavailableView {
                Label("Etkinlikler yüklenemedi", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error.message)
            } actions: {
                // Button'ın action'ı senkron: async işi bir Task başlatır.
                Button("Tekrar dene") {
                    Task { await store.refresh() }
                }
                .buttonStyle(.primary)
            }
        case .loaded:
            let events = store.visibleEvents
            List {
                if let error = store.refreshError {
                    OfflineNotice(error: error, updatedAt: store.updatedAt)
                }
                ForEach(events) { event in
                    NavigationLink(value: Route.event(id: event.id)) {
                        EventCard(event: event)
                    }
                }
            }
            // Boş bir List gruplu zemini çizmiyor (beyaz kalıyor); dolu ve boş
            // halde aynı zemin olsun diye List'in zemini gizlenip canvas konur.
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            // Boş durum List'in yerine değil üstüne: List yerinde kalınca
            // aşağı çekip yenileme boş listede de çalışır.
            .overlay {
                if events.isEmpty {
                    EmptyEventsView(isFiltered: store.filter.isActive || !store.filter.query.isEmpty)
                }
            }
            .refreshable {
                await store.refresh()
            }
        }
    }
}
