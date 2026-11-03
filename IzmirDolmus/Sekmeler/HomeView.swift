import DolmusCore
import SwiftUI

/// Anasayfa: en üstte "Nereye gitmek istiyorsun?", süren yolculuk varsa kartı ve
/// yol tarifi girişi, Ev/İş/Önemli Noktalar çipleri, etkinlik kartı; altında
/// konumun çevresinden geçen hatlar küçük bir haritada; en altta son aramalar
/// (Flutter'daki `HomeScreen`).
struct HomeView: View {
    @Environment(DataStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(UserStore.self) private var user
    @Environment(EventsStore.self) private var events
    @Environment(JourneySession.self) private var journeySession
    @Environment(\.weatherProvider) private var weatherProvider
    @Environment(\.routeTransitions) private var transitions
    @Environment(\.scenePhase) private var scenePhase

    @State private var model = HomeModel()
    /// Adresi seçilen kısayol (Ev ya da İş); `nil` ise sayfa kapalı.
    @State private var editingPlace: SavedPlaceKind?
    @State private var isShowingCategories = false

    /// Son aramalardan en çok bu kadarı.
    private static let recentLimit = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HomeHeader(weather: model.weather, credit: model.weatherCredit, district: model.district)
                if let current = journeySession.current {
                    ActiveJourneyCard(current: current) {
                        router.showOnMap(.journey(current.journey, from: current.from, to: current.to))
                    }
                    .padding(.top, 14)
                }
                SearchEntry {
                    router.planTrip()
                }
                .padding(.top, 14)
                shortcuts
                    .padding(.top, 12)
                NavigationLink(value: Route.events) {
                    EventsEntry(summary: eventsSummary)
                }
                .buttonStyle(.plain)
                .routeTransitionSource(.events, in: transitions)
                .padding(.top, 14)
                NearbySection(model: model) { place in
                    router.showOnMap(.place(place))
                } onRetry: {
                    Task { await model.locate(data: store.data, weatherProvider: weatherProvider) }
                }
                .padding(.top, 26)
                let recents = Array(user.recentPlaces.prefix(Self.recentLimit))
                if !recents.isEmpty {
                    RecentsSection(places: recents) { place in
                        router.showOnMap(.place(place))
                    } onDirections: { place in
                        router.planTrip(to: place)
                    } onClear: {
                        user.clearRecents()
                    }
                    .padding(.top, 22)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        // Aşağı çekince konum, hava durumu ve etkinlikler tazelenir.
        .refreshable {
            async let located: Void = model.locate(data: store.data, weatherProvider: weatherProvider)
            async let loaded: Void = events.refresh()
            _ = await (located, loaded)
        }
        // Başlık sayfanın içinde (büyük yazı); navigation bar yalnızca itilen
        // ekranlarda görünür.
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editingPlace) { kind in
            PlacePickerView(kind: kind, selection: binding(for: kind))
        }
        .sheet(isPresented: $isShowingCategories) {
            CategorySheet(center: model.surroundings?.here ?? .izmirCenter) { place in
                router.showOnMap(.place(place))
            }
        }
        .onAppear {
            model.startIfNeeded(data: store.data, weatherProvider: weatherProvider)
        }
        // Öne gelince eski ya da alınamamış konum yenilenir; arka planda beklenmez.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.refreshIfNeeded(data: store.data, weatherProvider: weatherProvider)
            case .background: model.pause()
            default: break
            }
        }
        .task {
            await events.load()
        }
    }

    // MARK: Kısayollar

    /// Ev · İş · Önemli Noktalar; sığmazsa yatay kaydırılır.
    private var shortcuts: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                savedPlaceChip(.home, place: user.home)
                savedPlaceChip(.work, place: user.work)
                ShortcutChip(title: "Önemli Noktalar", systemImage: "safari", isSet: true) {
                    isShowingCategories = true
                }
            }
        }
        .scrollIndicators(.hidden)
        // Kaydırma alanı kenara kadar; çipler sayfanın iç boşluğuyla hizalı.
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .padding(.horizontal, -20)
    }

    /// Kayıtlıysa oraya yol tarifi, değilse adresi sorar; basılı tutunca değiştir/kaldır.
    private func savedPlaceChip(_ kind: SavedPlaceKind, place: PlacePoint?) -> some View {
        ShortcutChip(title: kind.title, systemImage: kind.systemImage, isSet: place != nil) {
            if let place {
                router.planTrip(to: place)
            } else {
                editingPlace = kind
            }
        }
        .contextMenu {
            placeActions(kind, place: place)
        }
        // VoiceOver'da basılı tutma menüsünün aynı seçenekleri.
        .accessibilityActions {
            placeActions(kind, place: place)
        }
    }

    @ViewBuilder
    private func placeActions(_ kind: SavedPlaceKind, place: PlacePoint?) -> some View {
        Button {
            editingPlace = kind
        } label: {
            Label(place == nil ? "Adres ekle" : "Adresi değiştir", systemImage: "pencil")
        }
        if place != nil {
            Button(role: .destructive) {
                binding(for: kind).wrappedValue = nil
            } label: {
                Label("Kaldır", systemImage: "trash")
            }
        }
    }

    private func binding(for kind: SavedPlaceKind) -> Binding<PlacePoint?> {
        @Bindable var user = user
        return switch kind {
        case .home: $user.home
        case .work: $user.work
        }
    }

    // MARK: Etkinlikler

    private var eventsSummary: String {
        let thisWeek = events.events.filter { event in
            guard let start = event.start else { return false }
            return start >= .now && start < Date.now.addingTimeInterval(7 * 24 * 3600)
        }
        return switch (events.phase, thisWeek.count) {
        case (.loaded, let count) where count > 0: "Önümüzdeki 7 günde \(count) etkinlik"
        default: "İzmir’deki konserleri, tiyatroları ve daha fazlasını keşfet."
        }
    }
}
