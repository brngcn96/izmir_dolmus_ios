/// Uygulamanın salt okunur verisi: düzeltme kuralları uygulanmış hatlar,
/// güzergah çizgileri ve yer sözlüğü.
///
/// Bir kez kurulur, sonra değişmez. Değer tipi ve `Sendable` olduğu için ana
/// aktör dışında kurulup ana aktöre kopyalanmadan taşınabilir.
public struct DolmusData: Sendable {
    /// Bir ilçe ve o ilçeden geçen hatlar.
    public struct District: Sendable, Identifiable {
        public let name: String
        public let hats: [DolmusHat]

        public var id: String { name }
    }

    /// Ana hatlar, ada göre sıralı.
    public let hats: [DolmusHat]
    /// Hatlar ilçe başlıkları altında; ilçeler ve içlerindeki hatlar ada göre
    /// sıralı. Birden çok ilçeden geçen hat her ilçenin altında yer alır;
    /// ilçesi bilinmeyenler "Diğer"dedir.
    public let districts: [District]
    /// ESHOT durak adları ve diğer yer adları (yer sözlüğü).
    public let duraklar: [PlacePoint]
    /// Önemli noktalar: metro, İZBAN, hastane, AVM…
    public let landmarks: [Landmark]

    /// Hat kimliği → güzergah çizgileri, GİDİŞ önce.
    private let geomsByHat: [String: [HatGeom]]
    /// Hat kimliği → `hats` içindeki sırası.
    private let hatIndex: [String: Int]

    // Arama için önceden hesaplananlar; ilgili diziyle aynı sırada.
    let hatNameNorms: [String]
    let durakNorms: [String]
    /// Sözlükteki yer sıradan bir ESHOT durağı mı (okul, cadde vb. değil).
    let durakIsStop: [Bool]
    let landmarkNorms: [String]

    /// Çözülmüş dosya içeriklerinden kurar: güzergah adlarını temizler,
    /// düzeltme kurallarını uygular, satırları hatlara toplar ve arama
    /// dizinlerini hazırlar.
    init(
        routes rawRoutes: [DolmusRoute],
        geoms rawGeoms: [String: [RawHatGeom]],
        duraklar: [PlacePoint],
        landmarks: [Landmark]
    ) {
        // Güzergah çizgileri.
        let geoms = HatOverrides.applyGeoms(
            rawGeoms.mapValues { list in
                list.map(HatGeom.init(raw:)).filter { $0.points.count >= 2 }
            }
        )
        // Çizimde ve planlayıcıda GİDİŞ önce gelir; kendi içlerinde sıra korunur.
        func isGidis(_ geom: HatGeom) -> Bool { trNorm(geom.yon).dartContains("gidis") }
        geomsByHat = geoms.mapValues { list in
            list.filter(isGidis) + list.filter { !isGidis($0) }
        }

        // Ücret satırları hatlara toplanır; hatlar satırların ilk görüldüğü sırayla.
        var groupOrder: [String] = []
        var byGroup: [String: [DolmusRoute]] = [:]
        for route in HatOverrides.applyRoutes(rawRoutes) {
            if byGroup[route.groupID] == nil { groupOrder.append(route.groupID) }
            byGroup[route.groupID, default: []].append(route)
        }
        var hats = groupOrder.map { id in
            let segments = byGroup[id] ?? []
            return DolmusHat(
                id: id,
                name: segments.last?.groupName ?? id,
                segments: segments,
                apiCode: HatOverrides.apiCode(of: id)
            )
        }

        // Yalnızca geometri taşıyan bölmeler: bir bölme kuralının ücret satırı
        // yoksa (ör. "Buca - Manavkuyu") yukarıdaki satır bazlı listede hiç
        // görünmez. Listede ve aramada çıksın, haritada çizilsin diye her biri
        // için bağımsız bir hat açılır; ilçe ana hattan miras alınır.
        for split in HatOverrides.splits where byGroup[split.newID] == nil {
            guard let splitGeoms = geoms[split.newID], !splitGeoms.isEmpty else { continue }
            hats.append(DolmusHat(
                id: split.newID,
                name: split.newName,
                segments: [],
                apiCode: split.parentID,
                ilce: byGroup[split.parentID]?.first?.ilce
            ))
        }

        let sorted = hats
            .map { (hat: $0, norm: trNorm($0.name)) }
            .sorted { $0.norm.dartPrecedes($1.norm) }
        let sortedHats = sorted.map(\.hat)
        self.hats = sortedHats
        hatNameNorms = sorted.map(\.norm)
        hatIndex = Dictionary(
            sortedHats.enumerated().map { ($1.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // İlçeler. Hatlar ada göre sıralı olduğu için ilçe içi sıra da öyle.
        var districtOrder: [String] = []
        var byDistrict: [String: [DolmusHat]] = [:]
        for hat in sortedHats {
            let ilce = hat.ilce ?? ""
            let names = ilce.dartTrimmed().isEmpty
                ? ["Diğer"]
                : ilce.split(separator: "/").map { String($0).dartTrimmed() }.filter { !$0.isEmpty }
            for name in names {
                if byDistrict[name] == nil { districtOrder.append(name) }
                byDistrict[name, default: []].append(hat)
            }
        }
        districts = districtOrder
            .map { (district: District(name: $0, hats: byDistrict[$0] ?? []), norm: trNorm($0)) }
            .sorted { $0.norm.dartPrecedes($1.norm) }
            .map(\.district)

        // Yer sözlüğü.
        self.duraklar = duraklar
        self.landmarks = landmarks
        durakNorms = duraklar.map { trNorm($0.label) }
        durakIsStop = duraklar.map { PlaceClassifier.kind(of: $0.label) == "durak" }
        landmarkNorms = landmarks.map { trNorm($0.name) }
    }

    /// Kimliği verilen hat; yoksa `nil`.
    public func hat(id: String) -> DolmusHat? {
        hatIndex[id].map { hats[$0] }
    }

    /// Bir hattın haritada çizilecek güzergahları, GİDİŞ önce. Geometrisi
    /// olmayan hat için boş.
    public func geoms(for hatID: String) -> [HatGeom] {
        geomsByHat[hatID] ?? []
    }
}
