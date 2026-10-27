import DolmusCore
import MapKit
import Observation
import SwiftUI

/// Harita ekranının durumu ve mantığı (Flutter'daki `_MapScreenState`).
///
/// Üç görünüm var: boş harita; bir nokta seçilmiş (yakınından geçen hatlar,
/// listeden seçilenler renkli önizleme çizgisi); tek bir hat (resmi güzergahı,
/// gidiş/dönüş/varyant çipleri).
@Observable
final class MapModel {
    // MARK: Sabitler

    /// Kameranın gezebileceği alan: İzmir ve çevresi.
    static let cameraBounds = MapCameraBounds(
        centerCoordinateBounds: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.60, longitude: 27.30),
            span: MKCoordinateSpan(latitudeDelta: 1.50, longitudeDelta: 2.30)
        ),
        minimumDistance: 350,
        maximumDistance: 700_000
    )
    static let initialRegion = MKCoordinateRegion(
        center: Coordinate.izmirCenter.clCoordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.16, longitudeDelta: 0.19)
    )
    /// Yürünebilir "yakın" eşiği ve "biraz uzak" eşiği (m).
    static let nearRadius = 800.0
    static let farRadius = 2_000.0
    /// Bu zoom'un altında nokta (POI) çizilmez.
    static let poiMinZoom = 12.0
    /// Aynı anda en çok bu kadar nokta çizilir.
    static let poiLimit = 30
    /// Önizleme çizgilerinin renkleri; liste sırasıyla dağıtılır.
    static let previewColors: [Color] = [
        Color(hex: 0x1565C0), Color(hex: 0xC62828), Color(hex: 0x2E7D32),
        Color(hex: 0xE65100), Color(hex: 0x6A1B9A), Color(hex: 0x00838F),
    ]

    // MARK: Kamera

    var position: MapCameraPosition = .region(initialRegion)
    private(set) var region: MKCoordinateRegion?
    private(set) var zoom = 11.5
    /// Haritanın ekrandaki boyutu (pt); zoom ve dokunma toleransı için.
    var mapSize: CGSize = .zero
    /// Görünür alandaki noktalar, zoom'a göre süzülmüş.
    private(set) var pois: [MapPoi] = []
    /// Adı yazılacak noktalar (adları birbirine çarpmayanlar).
    private(set) var labeledIDs: Set<Int> = []

    // MARK: Tek hat

    private(set) var hat: DolmusHat?
    private(set) var geoms: [HatGeom] = []
    private(set) var geomIndex = 0
    /// Seçilen noktadan hatta binilebilecek en yakın yer.
    private(set) var boardPoint: Coordinate?
    private(set) var boardMeters: Double?

    // MARK: Seçilen nokta

    private(set) var probe: PlacePoint?
    private(set) var nearby: [NearbyHat] = []
    /// 800 m içinde hat yoksa 2 km içindeki en yakını (yalnızca bilgi için).
    private(set) var nearest: NearbyHat?
    /// Listeden seçilip haritaya çizilen hatlar; renk bu sıraya göre.
    private(set) var previewIDs: [String] = []
    var isShowingNearbyList = false
    /// Önizleme çizgisine dokununca altında kalan hatlar.
    private(set) var tappedHats: [DolmusHat] = []

    // MARK: Yol tarifi

    private(set) var tripFrom: PlacePoint?
    private(set) var tripTo: PlacePoint?
    /// Seçenekler, iyiden kötüye; ilki "önerilen".
    private(set) var journeys: [Journey] = []
    private(set) var journeyIndex = 0
    private(set) var isPlanning = false
    var isShowingJourneyList = false
    var isShowingSteps = false
    /// Kısa süre gösterilen bilgi (ör. rota bulunamadı).
    var message: String?
    /// Planlayıcı bir kez kurulur (ilk yol tarifinde); aynı anda gelen istekler
    /// aynı kurulumu bekler.
    private var plannerTask: Task<JourneyPlanner, Never>?
    /// Dolmuş bacaklarının renkleri, sırayla.
    static let rideColors: [Color] = [Color(hex: 0x1565C0), Color(hex: 0xE65100), Color(hex: 0x6A1B9A)]

    var selectedJourney: Journey? {
        journeys.indices.contains(journeyIndex) ? journeys[journeyIndex] : nil
    }

    var isTripActive: Bool {
        tripFrom != nil
    }

    var selectedGeom: HatGeom? {
        geoms.indices.contains(geomIndex) ? geoms[geomIndex] : nil
    }

    /// Haritada bir şey gösteriliyor mu (hat, seçilen nokta ya da yol tarifi).
    var hasOverlay: Bool {
        hat != nil || probe != nil || tripFrom != nil
    }

    func previewColor(for hatID: String) -> Color {
        guard let index = previewIDs.firstIndex(of: hatID) else { return .accent }
        return Self.previewColors[index % Self.previewColors.count]
    }

    // MARK: Seçilen nokta

    /// Noktayı işaretler, yakınından geçen hatları bulur ve noktayı ortalar.
    func setProbe(_ coordinate: Coordinate, label: String, data: DolmusData) {
        clearTrip()
        let list = data.nearbyHats(to: coordinate, maxMeters: Self.nearRadius)
        nearest = list.isEmpty ? data.nearbyHats(to: coordinate, maxMeters: Self.farRadius, limit: 1).first : nil
        hat = nil
        geoms = []
        geomIndex = 0
        boardPoint = nil
        boardMeters = nil
        probe = PlacePoint(label: label, coordinate: coordinate)
        nearby = list
        previewIDs = []
        tappedHats = []
        // Liste kendiliğinden açılmaz: altta "Hat listesi" ve "Yol tarifi" görünsün.
        isShowingNearbyList = false
        refreshPois(data: data)
        move(to: coordinate, zoom: max(zoom, 13))
    }

    func clearProbe() {
        probe = nil
        nearby = []
        nearest = nil
        previewIDs = []
        tappedHats = []
        isShowingNearbyList = false
    }

    /// Yakın hat listesinde bir hattın çizgisini aç/kapat.
    func togglePreview(_ hatID: String) {
        if let index = previewIDs.firstIndex(of: hatID) {
            previewIDs.remove(at: index)
        } else {
            previewIDs.append(hatID)
        }
        tappedHats = []
    }

    func previewAll() {
        previewIDs = nearby.map(\.hat.id)
    }

    func clearPreviews() {
        previewIDs = []
        tappedHats = []
    }

    // MARK: Tek hat

    /// Hattın resmi güzergahını çizer. Bir noktadan açıldıysa o noktaya en yakın
    /// güzergah (gidiş/dönüş/varyant) önce gösterilir.
    func showHat(_ hatID: String, data: DolmusData) {
        guard let hat = data.hat(id: hatID) else { return }
        clearTrip()
        self.hat = hat
        geoms = data.geoms(for: hatID)
        geomIndex = probe.map { data.nearestGeomIndex(of: hatID, to: $0.coordinate) } ?? 0
        nearby = []
        previewIDs = []
        tappedHats = []
        isShowingNearbyList = false
        updateBoardPoint()
        fitSelectedGeom()
    }

    func selectGeom(_ index: Int) {
        guard geoms.indices.contains(index) else { return }
        geomIndex = index
        updateBoardPoint()
        fitSelectedGeom()
    }

    /// Çipteki ad: yön tekse yön ("GİDİŞ"), değilse güzergah adı (kısaltılmış).
    func label(for geom: HatGeom) -> String {
        let yon = geom.yon.trimmingCharacters(in: .whitespaces)
        if !yon.isEmpty, geoms.filter({ $0.yon.trimmingCharacters(in: .whitespaces) == yon }).count == 1 {
            return yon
        }
        let ad = geom.ad.trimmingCharacters(in: .whitespaces)
        guard ad.count > 26 else { return ad }
        return "\(ad.prefix(14))…\(ad.suffix(10))"
    }

    private func updateBoardPoint() {
        guard let probe, let geom = selectedGeom, let hit = geom.nearestBoardable(to: probe.coordinate) else {
            boardPoint = nil
            boardMeters = nil
            return
        }
        boardPoint = hit.point
        boardMeters = hit.meters
    }

    private func fitSelectedGeom() {
        guard let geom = selectedGeom, geom.points.count >= 2 else { return }
        fit(geom.points + (probe.map { [$0.coordinate] } ?? []))
    }

    // MARK: Geri

    /// Bir adım geri: hat → (nokta varsa) yakın hatlar → boş harita.
    /// - Returns: Harita boşaldıysa `true`; çağıran geldiği sekmeye dönebilir.
    func back(data: DolmusData) -> Bool {
        if tripFrom != nil {
            clear()
            return true
        }
        if hat != nil {
            if let probe {
                setProbe(probe.coordinate, label: probe.label, data: data)
                return false
            }
            clear()
            return true
        }
        // Nokta kalkınca harita boştur: başka sekmeden (ör. etkinlikten "Haritada
        // göster") gelindiyse oraya dönülür.
        clearProbe()
        return true
    }

    func clear() {
        clearTrip()
        hat = nil
        geoms = []
        geomIndex = 0
        boardPoint = nil
        boardMeters = nil
        clearProbe()
    }

    // MARK: Yol tarifi

    /// Nereden → Nereye: planlayıcıyı ana aktör dışında çalıştırır, sonucu gösterir.
    func startTrip(from: PlacePoint, to: PlacePoint, data: DolmusData) async {
        hat = nil
        geoms = []
        geomIndex = 0
        boardPoint = nil
        boardMeters = nil
        clearProbe()
        tripFrom = from
        tripTo = to
        journeys = []
        journeyIndex = 0
        isPlanning = true
        message = nil
        fit([from.coordinate, to.coordinate])

        let planner = await journeyPlanner(data: data)
        let found = await planner.planTrip(from: from.coordinate, to: to.coordinate, data: data)
        // Bu arada başka bir yol tarifi ya da görünüm seçildiyse sonucu bırak.
        guard tripFrom == from, tripTo == to else { return }
        isPlanning = false
        guard !found.isEmpty else {
            // Uçlardan biri yayaya kapalı bir alandaysa (havalimanı) onun notu;
            // başlangıç öyle değilse çevresindeki hatlar gösterilir.
            let note = WalkBarriers.note(for: to.coordinate) ?? WalkBarriers.note(for: from.coordinate)
            clearTrip()
            if WalkBarriers.note(for: from.coordinate) == nil {
                setProbe(from.coordinate, label: from.label, data: data)
            }
            message = note ?? "“\(from.label)” → “\(to.label)” için dolmuşla ulaşım bulunamadı (çok uzak ya da yürüme mesafesi fazla). Başlangıç çevresindeki hatlar gösteriliyor."
            return
        }
        journeys = found
        journeyIndex = 0
        isShowingJourneyList = true
        fitSelectedJourney()
    }

    func selectJourney(_ index: Int) {
        guard journeys.indices.contains(index) else { return }
        journeyIndex = index
        isShowingJourneyList = false
        fitSelectedJourney()
    }

    func clearTrip() {
        tripFrom = nil
        tripTo = nil
        journeys = []
        journeyIndex = 0
        isPlanning = false
        isShowingJourneyList = false
        isShowingSteps = false
    }

    private func journeyPlanner(data: DolmusData) async -> JourneyPlanner {
        if let plannerTask {
            return await plannerTask.value
        }
        let task = Task { await JourneyPlanner.build(from: data) }
        plannerTask = task
        return await task.value
    }

    private func fitSelectedJourney() {
        guard let journey = selectedJourney else { return }
        var points: [Coordinate] = []
        for leg in journey.legs {
            switch leg {
            case .walk(let walk): points += [walk.from, walk.to]
            case .ride(let ride): points += ride.ridePoints
            }
        }
        fit(points)
    }

    // MARK: Kamera ve noktalar

    /// Kamera durunca: zoom'u hesaplar, görünür alandaki noktaları yeniler.
    func cameraChanged(to region: MKCoordinateRegion, data: DolmusData) {
        self.region = region
        zoom = Self.zoom(for: region, width: mapSize.width)
        refreshPois(data: data)
    }

    private func refreshPois(data: DolmusData) {
        guard let region, zoom >= Self.poiMinZoom, mapSize.width > 0 else {
            pois = []
            labeledIDs = []
            return
        }
        let box = GeoBox(
            south: region.center.latitude - region.span.latitudeDelta / 2,
            north: region.center.latitude + region.span.latitudeDelta / 2,
            west: region.center.longitude - region.span.longitudeDelta / 2,
            east: region.center.longitude + region.span.longitudeDelta / 2
        )
        // Üst üste binmesin: noktalar önem sırasıyla (poisInView'in sırası) ekrana
        // yerleştirilir. Simgesi daha önemli bir ada ya da simgeye çarpan nokta bu
        // zoom'da çizilmez (yakınlaşınca çıkar); adı çarpanın adı yazılmaz, simgesi
        // olmayan (mahalle, kafe…) o zaman hiç çizilmez.
        func screenPoint(_ coordinate: Coordinate) -> CGPoint {
            CGPoint(
                x: (coordinate.longitude - box.west) / (box.east - box.west) * mapSize.width,
                y: (box.north - coordinate.latitude) / (box.north - box.south) * mapSize.height
            )
        }
        var occupied: [CGRect] = []
        // Seçilen nokta ve yol tarifinin uçları önce: iğneleri ve altlarındaki adları
        // örtülmesin (MapKit, başka bir işarete çarpan iğnenin adını gizliyor).
        for place in [probe, tripFrom, tripTo].compactMap({ $0 }) {
            let point = screenPoint(place.coordinate)
            let width = min(CGFloat(place.label.count) * 6.5, 160) + 8
            occupied.append(CGRect(x: point.x - 18, y: point.y - 36, width: 36, height: 36))
            occupied.append(CGRect(x: point.x - width / 2, y: point.y, width: width, height: 30))
        }
        var areaCenters: [CGPoint] = []
        var labeled: Set<Int> = []
        var result: [MapPoi] = []
        // Çarpışıp atlananların yerine sıradakiler gelsin diye adaylar iki katı.
        for poi in data.poisInView(box, zoom: zoom, limit: Self.poiLimit * 2) where result.count < Self.poiLimit {
            let point = screenPoint(poi.coordinate)
            let isArea = poi.type == "mahalle"
            // Mahalle adları seyrek kalsın: başka bir mahalle adına ~110 pt'den yakınsa atlanır.
            if isArea, areaCenters.contains(where: { abs($0.x - point.x) < 110 && abs($0.y - point.y) < 110 }) {
                continue
            }
            let hasIcon = !isArea && !PoiStyle(type: poi.type).isIconless
            // PoiMarker'ın simgesi: üst ortası koordinatta, 22 pt.
            let icon = CGRect(x: point.x - 11, y: point.y, width: 22, height: 22)
            if hasIcon, occupied.contains(where: { $0.intersects(icon.insetBy(dx: 3, dy: 3)) }) {
                continue
            }
            if isArea || zoomShowsLabel(poi) {
                let label = Self.labelFrame(poi, at: point, isArea: isArea, hasIcon: hasIcon)
                if !occupied.contains(where: { $0.intersects(label) }) {
                    labeled.insert(poi.id)
                    occupied.append(label)
                }
            }
            if hasIcon {
                occupied.append(icon)
            } else if !labeled.contains(poi.id) {
                continue
            }
            if isArea {
                areaCenters.append(point)
            }
            result.append(poi)
        }
        pois = result
        labeledIDs = labeled
    }

    /// Noktanın adı yazılsın mı (zoom yetiyor ve başka bir ada çarpmıyor).
    func isLabeled(_ poi: MapPoi) -> Bool {
        labeledIDs.contains(poi.id)
    }

    /// Noktanın adı bu zoom'da yazılabilir mi. Durak ve eczane zaten en son zoom'da
    /// çıktığı için adları hemen; diğerlerinde bir zoom sonra.
    private func zoomShowsLabel(_ poi: MapPoi) -> Bool {
        poi.type == "eczane" || poi.type == "durak" ? zoom >= poi.minZoom : zoom >= poi.minZoom + 1
    }

    /// Adın ekranda kaplayacağı yer, PoiMarker'ın düzenine göre tahmini: mahalle
    /// adı koordinatta ortalı (büyük harf); diğerlerinde simgenin altında, en çok 120 pt.
    private static func labelFrame(_ poi: MapPoi, at point: CGPoint, isArea: Bool, hasIcon: Bool) -> CGRect {
        let name = poi.label.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? poi.label
        if isArea {
            let width = CGFloat(name.count) * 7.5 + 4
            return CGRect(x: point.x - width / 2, y: point.y - 8, width: width, height: 16)
        }
        let width = min(CGFloat(name.count) * 6.3, 120) + 4
        return CGRect(x: point.x - width / 2, y: point.y + (hasIcon ? 23 : 0), width: width, height: 15)
    }

    /// Web haritalarındaki zoom düzeyi (256 pt'lik karolar): Flutter'daki
    /// eşikler bununla karşılaştırılır.
    static func zoom(for region: MKCoordinateRegion, width: CGFloat) -> Double {
        guard width > 0, region.span.longitudeDelta > 0 else { return 11.5 }
        return log2(360 * Double(width) / (256 * region.span.longitudeDelta))
    }

    // MARK: Çizgiye dokunma

    /// Önizleme çizgilerinden dokunulan noktanın altındakileri bulur.
    func identifyLines(at coordinate: Coordinate, data: DolmusData) {
        guard hat == nil, !previewIDs.isEmpty, let region, mapSize.height > 0 else {
            tappedHats = []
            return
        }
        let metersPerPoint = region.span.latitudeDelta * 111_320 / Double(mapSize.height)
        tappedHats = data.hats(onLinesOf: previewIDs, near: coordinate, toleranceMeters: 16 * metersPerPoint)
    }

    func dismissTappedHats() {
        tappedHats = []
    }

    // MARK: Kamera hareketleri

    func move(to coordinate: Coordinate, zoom targetZoom: Double) {
        let width = max(Double(mapSize.width), 320)
        let longitudeDelta = 360 * width / (256 * pow(2, targetZoom))
        let height = max(Double(mapSize.height), 480)
        let latitudeDelta = longitudeDelta * height / width * cos(coordinate.latitude * .pi / 180)
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: coordinate.clCoordinate,
                span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            ))
        }
    }

    func fit(_ points: [Coordinate]) {
        guard let first = points.first else { return }
        var south = first.latitude, north = first.latitude, west = first.longitude, east = first.longitude
        for point in points {
            south = min(south, point.latitude)
            north = max(north, point.latitude)
            west = min(west, point.longitude)
            east = max(east, point.longitude)
        }
        // Kenarlarda pay: çizgi ekranın kenarına yapışmasın.
        let latitudeDelta = max((north - south) * 1.35, 0.004)
        let longitudeDelta = max((east - west) * 1.35, 0.004)
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: (south + north) / 2, longitude: (west + east) / 2),
                span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            ))
        }
    }
}

extension NearbyHat {
    /// "~350 m" ya da "1,2 km".
    var distanceLabel: String {
        Self.distanceLabel(meters)
    }

    static func distanceLabel(_ meters: Double) -> String {
        if meters < 950 {
            return "~\(Int((meters / 50).rounded()) * 50) m"
        }
        return "\((meters / 1000).formatted(.number.precision(.fractionLength(1)).locale(.turkish))) km"
    }
}

extension Color {
    /// 0xRRGGBB biçiminde renk.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
