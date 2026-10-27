import DolmusCore
import SwiftUI

/// "Nereden → Nereye": iki yer seç, rotaları haritada gör.
struct TripPlannerView: View {
    @Environment(DataStore.self) private var store
    @Environment(UserStore.self) private var user
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    enum Field: Hashable {
        case from
        case to
    }

    static let myLocationLabel = "Konumunuz"

    @State private var from: PlacePoint?
    @State private var to: PlacePoint?
    @State private var fromText: String
    @State private var toText: String
    @FocusState private var focus: Field?
    @State private var suggestions: [PlacePoint] = []
    @State private var location = LocationProvider()
    @State private var locationError: LocationError?

    init(draft: TripDraft) {
        _from = State(initialValue: draft.from)
        _to = State(initialValue: draft.to)
        _fromText = State(initialValue: draft.from?.label ?? "")
        _toText = State(initialValue: draft.to?.label ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    field(.from, text: $fromText, prompt: "Nereden", symbol: "circle.circle")
                    field(.to, text: $toText, prompt: "Nereye", symbol: "mappin.circle.fill")
                } footer: {
                    HStack {
                        Spacer()
                        Button {
                            swap(&from, &to)
                            swap(&fromText, &toText)
                        } label: {
                            Label("Yer değiştir", systemImage: "arrow.up.arrow.down")
                                .font(.figtree(.footnote, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                    }
                }
                if showsSuggestions {
                    Section("Öneriler") {
                        ForEach(suggestions, id: \.self) { place in
                            placeRow(place, symbol: "mappin.and.ellipse")
                        }
                    }
                } else {
                    if user.home != nil || user.work != nil {
                        Section("Kısayollar") {
                            if let home = user.home {
                                placeRow(home, symbol: "house.fill", title: "Ev")
                            }
                            if let work = user.work {
                                placeRow(work, symbol: "briefcase.fill", title: "İş")
                            }
                        }
                    }
                    if !user.recentPlaces.isEmpty {
                        Section("Son aramalar") {
                            ForEach(user.recentPlaces, id: \.self) { place in
                                placeRow(place, symbol: "clock.arrow.circlepath")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Yol tarifi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: plan) {
                    Label("Rota bul", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.figtree(.headline, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .disabled(from == nil || to == nil || from == to)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            // Yazarken her harfte değil, yazmaya ara verince ara: yeni harf gelince
            // önceki görev iptal edilir, 200 ms dolmadan aramaya geçilmez.
            .task(id: query) {
                guard query.count >= 2 else {
                    suggestions = []
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                suggestions = store.data.placeMatches(query, limit: 25, near: .izmirCenter)
            }
            .alert("Konum", isPresented: Binding(get: { locationError != nil }, set: { if !$0 { locationError = nil } })) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(locationError?.message ?? "")
            }
            .onAppear {
                focus = from == nil ? .from : (to == nil ? .to : nil)
            }
        }
    }

    // MARK: Parçalar

    private func field(_ field: Field, text: Binding<String>, prompt: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(field == .from ? Color.secondary : Color.accent)
            TextField(prompt, text: text)
                .focused($focus, equals: field)
                .submitLabel(field == .from ? .next : .search)
                .onSubmit {
                    if field == .from { focus = .to } else { plan() }
                }
                // Yazı seçilen yerin adından değişirse seçim bozulur: öneriden seçilmeli.
                .onChange(of: text.wrappedValue) { _, newValue in
                    switch field {
                    case .from where newValue != from?.label: from = nil
                    case .to where newValue != to?.label: to = nil
                    default: break
                    }
                }
            Button {
                Task { await useMyLocation(for: field) }
            } label: {
                if location.isLocating {
                    ProgressView()
                } else {
                    Image(systemName: "location.fill")
                }
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Konumumu kullan")
        }
    }

    private func placeRow(_ place: PlacePoint, symbol: String, title: String? = nil) -> some View {
        Button {
            pick(place)
        } label: {
            Label(title ?? place.label, systemImage: symbol)
                .foregroundStyle(Color.primary)
        }
    }

    // MARK: Eylemler

    /// Odaktaki alanın metni (öneriler bunun için).
    private var query: String {
        switch focus {
        case .from: from == nil ? fromText : ""
        case .to: to == nil ? toText : ""
        case nil: ""
        }
    }

    private var showsSuggestions: Bool {
        query.count >= 2
    }

    /// Seçilen yeri odaktaki alana (odak yoksa boş olana) koyar, sonrakine geçer.
    private func pick(_ place: PlacePoint) {
        let target = focus ?? (from == nil ? .from : .to)
        switch target {
        case .from:
            from = place
            fromText = place.label
            focus = to == nil ? .to : nil
        case .to:
            to = place
            toText = place.label
            focus = nil
        }
        suggestions = []
    }

    private func useMyLocation(for field: Field) async {
        do {
            let coordinate = try await location.currentLocation()
            focus = field
            pick(PlacePoint(label: Self.myLocationLabel, coordinate: coordinate))
        } catch {
            locationError = error
        }
    }

    private func plan() {
        guard let from, let to, from != to else { return }
        for place in [from, to] where place.label != Self.myLocationLabel {
            user.addRecent(place)
        }
        dismiss()
        router.showOnMap(.trip(from: from, to: to))
    }
}
