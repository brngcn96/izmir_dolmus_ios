/// Elle yapılan editoryal düzeltmeler. İBB verisinde bir hat kodunun altında,
/// aslında o hatta ait olmayan ya da eskimiş güzergahlar olabiliyor; bazı
/// kodlar da tek başlık altında ayrı dolmuşları taşıyor.
///
/// Flutter tarafındaki `hat_overrides.dart`'ın karşılığıdır; ikisi elle eşit
/// tutulur, sapmayı altın dosya testleri yakalar.
enum HatOverrides {
    /// Eşleştirme anahtarı: Türkçe sadeleştir, harf/rakam dışını at.
    /// "KARŞIYAKA - EVKA 5" → "karsiyakaevka5"
    static func key(_ text: String) -> String {
        String(trNorm(text).unicodeScalars.filter { scalar in
            ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar)
        })
    }

    // MARK: Çıkarma

    /// Bir hat kodunun altından çıkarılacak güzergah (harita geometrisi) mı?
    /// `k`: güzergah adının anahtarı.
    private static func dropsGeom(code: String, key k: String) -> Bool {
        switch code {
        // Düz "Karşıyaka - Evka 5" eski; yerini "Katip Çelebi Ü. - Evka 5"
        // aldı (o zaten var). Yalnızca düz Evka 5 silinir.
        case "M02": k.contains("evka5") && !k.contains("katip")
        // "Körfez Mahallesi" güzergahı kaldırıldı.
        case "M06": k.contains("korfez")
        // Eski "Bayraklı - Naldöken" (Doğanlar'sız) kaldırıldı.
        case "M13": k.contains("naldoken") && !k.contains("doganlar")
        // Eski düz "Yeşilyurt - Otogar - Bornova" kaldırıldı; yenisi "(Şehir
        // Hastanesi yolu ile) (RİNG)" kalır. "Yeşilyurt - Kuruçeşme (RİNG)"
        // diye bir dolmuş gerçekte yok; o geometri de atılır.
        case "M21":
            (k.contains("otogar") && k.contains("bornova") && !k.contains("sehirhastanesi"))
                || k.contains("kurucesme")
        // "Hal - Gıda Çarşısı" diye dolmuş yok. "Buca - Gıda" kalır.
        case "M26": k.contains("halgida")
        // "Buca Hal - Otogar" diye dolmuş yok. "Buca - Otogar" kalır.
        case "M33": k.contains("bucahal")
        // "Yeşilyurt - Kuruçeşme (RİNG)" gerçekte yok (İBB verisinde M21 ile
        // aynı geometri mükerrer duruyordu). "Buca - Yeşilyurt" kalır.
        case "M34": k.contains("kurucesme")
        default: false
        }
    }

    /// Bir hat kodunun altından çıkarılacak ücret satırı mı? Yalnızca açıkça
    /// kaldırılan bir güzergaha ait satırlar için. `k`: satır adının anahtarı.
    private static func dropsRoute(groupID: String, key k: String) -> Bool {
        switch groupID {
        // Körfez güzergahı gidince ücret satırı da anlamsız kalıyor.
        case "M06": k.contains("korfez")
        default: false
        }
    }

    // MARK: Hat bölme

    /// Bir hat kodunun altından ayrılıp yeni hat olacak koridor.
    ///
    /// Bazı İBB kodları tek başlık altında ayrı dolmuşları taşıyor (ör. M41
    /// "Gediz-Işıkkent" kodunun altında bir de "Mevlana-Buca" var). İnsanlar
    /// yanlış araca binmesin diye bunlar ayrı hat olarak açılır: ana kodun
    /// altından kurala uyan güzergah ve ücret satırları yeni hatta toplanır.
    struct Split: Sendable {
        /// Ana İBB kodu (ör. "M41"); yeni hat ücretini bu koddan çeker.
        let parentID: String
        /// Türetilmiş hat kimliği (ör. "M41#buca").
        let newID: String
        let newName: String
        /// Güzergah ya da satır adının anahtarı bu bölmeye ait mi.
        let matches: @Sendable (_ key: String) -> Bool
    }

    /// Sıra önemli: bir güzergah, ana kodu tutan ilk kurala gider.
    static let splits: [Split] = [
        Split(parentID: "M41", newID: "M41#buca", newName: "Mevlana - Buca") { k in
            k.contains("buca") || k.contains("mevlana")
        },
        Split(parentID: "M08", newID: "M08#cengizhan", newName: "Karşıyaka - Cengizhan") { k in
            k.contains("cengizhan")
        },
        Split(parentID: "M12", newID: "M12#mevlana", newName: "Atatürk Mah. - Mevlana Mah.") { k in
            k.contains("mevlana")
        },
        Split(parentID: "M22", newID: "M22#evka7", newName: "Evka 7 - Uzundere - TOKİ") { k in
            k.contains("evka7")
        },
        Split(parentID: "M29", newID: "M29#eskicamlik", newName: "F. Altay - Yeşilyurt - Eskiçamlık") { k in
            k.contains("eskicamlik") || k.contains("fahrettinaltay") || k.contains("faltay")
        },
        Split(parentID: "M31", newID: "M31#basin", newName: "Gaziemir - Basın Sitesi") { k in
            k.contains("basin")
        },
        Split(parentID: "M35", newID: "M35#toki", newName: "TOKİ - Uzundere - Işıkkent") { k in
            k.contains("toki") || k.contains("uzundere")
        },
        Split(parentID: "M43", newID: "M43#otogar", newName: "Çay Mahallesi - Otogar") { k in
            k.contains("otogar")
        },
        // M01 üç ayrı hedef taşıyor: ana "Egekent" kalır, diğer ikisi ayrılır.
        Split(parentID: "M01", newID: "M01#aosb", newName: "Karşıyaka - AOSB") { k in
            k.contains("aosb") || k.contains("organizesanayi")
        },
        Split(parentID: "M01", newID: "M01#harmandali", newName: "Karşıyaka - Harmandalı") { k in
            k.contains("harmandali") || k.contains("katipcelebi") || k.contains("kcelebiuni")
        },
        // M39: ana "F.Altay-Güzelbahçe" kalır; Mimkent kolları ayrılır.
        Split(parentID: "M39", newID: "M39#sahilevleri", newName: "Mimkent - Sahilevleri") { k in
            k.contains("sahilevleri")
        },
        Split(parentID: "M39", newID: "M39#narbel", newName: "Narbel - Mimkent") { k in
            k.contains("narbel")
        },
        // Aşağıdakilerin kendi ücret satırı yok: yalnızca harita güzergahı
        // taşıyan ayrı hatlar.
        Split(parentID: "M19", newID: "M19#manavkuyu", newName: "Buca - Manavkuyu") { k in
            k.contains("manavkuyu")
        },
        Split(parentID: "M20", newID: "M20#sehirhastanesi", newName: "Pınarbaşı - Şehir Hastanesi") { k in
            k.contains("sehirhastanesi")
        },
    ]

    /// Hat kimliği → gerçek İBB kodu (ücret servisi için). Bölünmüş hatlarda ana kod.
    static func apiCode(of hatID: String) -> String {
        splits.first { $0.newID == hatID }?.parentID ?? hatID
    }

    /// `parentID` altındaki bir güzergah/satır bir bölmeye ait mi? Uyan ilk kural.
    private static func splitTarget(parentID: String, key: String) -> Split? {
        splits.first { $0.parentID == parentID && $0.matches(key) }
    }

    // MARK: Ters dosyalanmış geometriler

    /// Geometrileri İBB verisinde ters dosyalanmış hat çiftleri.
    private static let swappedGeoms: [(String, String)] = [
        // ÇEŞ01 "(ESKİ YOL)" hattının altında otoyol geometrisi, ÇEŞ02 "OTOYOL"
        // hattının altında eski yol geometrisi duruyordu; haritada ters
        // görünüyordu. Doğrulandı: ÇEŞ01 noktaları Urla'ya 1025 m (girmiyor,
        // 117 km), ÇEŞ02 noktaları Urla'dan 494 m (geçiyor, 87 km).
        ("ÇEŞ01", "ÇEŞ02"),
    ]

    // MARK: Bilgi notu

    /// Hat detayında herkese gösterilen editoryal not (kullanıcının kişisel
    /// notundan ayrı); yoksa `nil`.
    static func info(for hatID: String) -> String? {
        switch hatID.dartTrimmed() {
        // ÇEŞME - OTOYOL: bu hatta dolmuş değil, seyahat firması araçları çalışır.
        case "ÇEŞ02": "Bu güzergahta dolmuş değil, üzerinde \"ÇEŞME SEYAHAT\" yazan araçlar çalışır."
        default: nil
        }
    }

    // MARK: Uygulama

    /// Geometrileri düzeltir: önce çıkarmalar, sonra bölme kurallarına uyan
    /// güzergahların yeni hat koduna taşınması, en son ters çiftlerin takası.
    static func applyGeoms(_ geoms: [String: [HatGeom]]) -> [String: [HatGeom]] {
        var out: [String: [HatGeom]] = [:]
        for (code, list) in geoms {
            let parent = code.dartTrimmed()
            var remaining: [HatGeom] = []
            for geom in list {
                let key = key(geom.ad)
                if dropsGeom(code: parent, key: key) { continue }
                if let target = splitTarget(parentID: parent, key: key) {
                    out[target.newID, default: []].append(geom)
                } else {
                    remaining.append(geom)
                }
            }
            out[code, default: []].append(contentsOf: remaining)
        }
        for (a, b) in swappedGeoms {
            if let geomsA = out[a], let geomsB = out[b] {
                out[a] = geomsB
                out[b] = geomsA
            }
        }
        return out
    }

    /// Ücret satırlarını düzeltir: çıkar, sonra bölme kurallarına göre taşı.
    static func applyRoutes(_ routes: [DolmusRoute]) -> [DolmusRoute] {
        var out: [DolmusRoute] = []
        out.reserveCapacity(routes.count)
        for route in routes {
            let groupID = route.groupID.dartTrimmed()
            let key = key(route.name)
            if dropsRoute(groupID: groupID, key: key) { continue }
            if let target = splitTarget(parentID: groupID, key: key) {
                out.append(route.reassigned(toGroup: target.newID, name: target.newName))
            } else {
                out.append(route)
            }
        }
        return out
    }
}
