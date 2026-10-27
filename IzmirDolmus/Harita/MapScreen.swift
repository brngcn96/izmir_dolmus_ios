import DolmusCore
import MapKit
import SwiftUI

/// Harita sekmesi: hat güzergahları, uzun basınca "Seçilen nokta" ve yakınından
/// geçen hatlar, yakınlaştıkça duraklar ve önemli noktalar, konumum.
struct MapScreen: View {
    @Environment(DataStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(UserStore.self) private var user

    @State private var model = MapModel()
    @State private var location = LocationProvider()
    @State private var isSearching = false
    @State private var isShowingCategories = false
    @State private var locationError: LocationError?

    var body: some View {
        @Bindable var model = model
        MapReader { proxy in
            Map(position: $model.position, bounds: MapModel.cameraBounds) {
                mapContent
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                model.cameraChanged(to: context.region, data: store.data)
            }
            // Dokunma: önizleme çizgilerinden hangisine dokunulduğunu bul.
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                model.identifyLines(at: Coordinate(coordinate), data: store.data)
            }
            // Uzun basma: o noktayı seç, yakınından geçen hatları göster.
            .gesture(LongPressLocationGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                model.setProbe(Coordinate(coordinate), label: "Seçilen nokta", data: store.data)
            })
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                model.mapSize = size
            }
        }
        .safeAreaInset(edge: .top) {
            topControls
        }
        .safeAreaInset(edge: .bottom) {
            bottomPanel
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $model.isShowingNearbyList) {
            NearbyListSheet(model: model) { hatID in
                model.showHat(hatID, data: store.data)
            }
            .presentationDetents([.height(240), .fraction(0.45)])
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.45)))
        }
        .sheet(isPresented: $isShowingCategories) {
            CategorySheet(center: mapCenter) { place in
                model.setProbe(place.coordinate, label: place.label, data: store.data)
            }
        }
        .sheet(isPresented: $isSearching) {
            MapSearchSheet(near: mapCenter) { place in
                model.setProbe(place.coordinate, label: place.label, data: store.data)
            }
        }
        .alert("Konum", isPresented: Binding(get: { locationError != nil }, set: { if !$0 { locationError = nil } })) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(locationError?.message ?? "")
        }
        // Başka sekmeden "Haritada göster".
        .onChange(of: router.mapRequest, initial: true) { _, request in
            guard let request else { return }
            router.mapRequest = nil
            switch request {
            case .hat(let id):
                model.clearProbe()
                model.showHat(id, data: store.data)
            case .place(let place):
                model.setProbe(place.coordinate, label: place.label, data: store.data)
            }
        }
    }

    // MARK: Harita içeriği

    @MapContentBuilder
    private var mapContent: some MapContent {
        // Seçili hattın güzergahı: beyaz kenar üstünde marka rengi.
        if let geom = model.selectedGeom {
            let coordinates = geom.points.map(\.clCoordinate)
            MapPolyline(coordinates: coordinates)
                .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: coordinates)
                .stroke(Color.accent.opacity(0.9), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
        // Yakın hat önizlemeleri, listedeki renkleriyle.
        if model.hat == nil {
            ForEach(model.previewIDs, id: \.self) { hatID in
                MapPolyline(coordinates: previewLine(for: hatID))
                    .stroke(model.previewColor(for: hatID).opacity(0.85), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        ForEach(model.pois) { poi in
            Annotation(poi.label, coordinate: poi.coordinate.clCoordinate, anchor: poi.type == "mahalle" ? .center : .top) {
                PoiMarker(poi: poi, isLabeled: model.isLabeled(poi))
                    .onTapGesture {
                        let marker = PoiMarker(poi: poi, isLabeled: true)
                        model.setProbe(poi.coordinate, label: marker.name, data: store.data)
                    }
            }
            .annotationTitles(.hidden)
        }
        if let board = model.boardPoint {
            Annotation("Biniş", coordinate: board.clCoordinate) {
                Circle()
                    .fill(Color.green)
                    .stroke(.white, lineWidth: 2)
                    .frame(width: 14, height: 14)
            }
        }
        if let probe = model.probe {
            Annotation(probe.label, coordinate: probe.coordinate.clCoordinate, anchor: .bottom) {
                ProbePin()
            }
        }
        UserAnnotation()
    }

    private func previewLine(for hatID: String) -> [CLLocationCoordinate2D] {
        store.data.geoms(for: hatID).first?.points.map(\.clCoordinate) ?? []
    }

    private var mapCenter: Coordinate {
        model.region.map { Coordinate($0.center) } ?? .izmirCenter
    }

    // MARK: Üst kontroller

    private var topControls: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    if model.hasOverlay {
                        Button(action: goBack) {
                            Image(systemName: "chevron.backward")
                                .font(.title3.weight(.semibold))
                                .frame(width: 48, height: 48)
                        }
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel("Geri")
                    }
                    if model.hat == nil {
                        Button {
                            isSearching = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                Text("Haritada arayın")
                                    .font(.figtree(.body))
                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                    } else {
                        Spacer()
                    }
                    Button {
                        Task { await locate() }
                    } label: {
                        Group {
                            if location.isLocating {
                                ProgressView()
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.title3)
                                    .foregroundStyle(.accent)
                            }
                        }
                        .frame(width: 48, height: 48)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Konumum")
                }
                if model.hat == nil {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            if let home = user.home {
                                chip("Ev", systemImage: "house.fill") {
                                    model.setProbe(home.coordinate, label: "Ev", data: store.data)
                                }
                            }
                            if let work = user.work {
                                chip("İş", systemImage: "briefcase.fill") {
                                    model.setProbe(work.coordinate, label: "İş", data: store.data)
                                }
                            }
                            chip("Önemli Noktalar", systemImage: "safari") {
                                isShowingCategories = true
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func chip(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.figtree(.subheadline, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    // MARK: Alt panel

    private var bottomPanel: some View {
        VStack(spacing: 10) {
            if !model.tappedHats.isEmpty {
                TappedLinesCard(model: model, hats: model.tappedHats) { hatID in
                    model.showHat(hatID, data: store.data)
                }
            }
            if let hat = model.hat {
                RouteBanner(model: model, hat: hat) {
                    router[.map].append(.hat(id: hat.id))
                } onClose: {
                    model.clear()
                    withAnimation { model.position = .region(MapModel.initialRegion) }
                }
            } else if model.probe != nil {
                ProbePanel(model: model) { hatID in
                    model.showHat(hatID, data: store.data)
                }
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: Eylemler

    /// Bir adım geri; harita boşaldıysa ve başka sekmeden gelindiyse oraya dön.
    private func goBack() {
        guard model.back(data: store.data) else { return }
        if let tab = router.mapReturnTab {
            router.mapReturnTab = nil
            router.selectedTab = tab
        }
    }

    private func locate() async {
        do {
            let coordinate = try await location.currentLocation()
            model.setProbe(coordinate, label: "Konumum", data: store.data)
        } catch {
            locationError = error
        }
    }
}
