import Testing
@testable import DolmusCore

// Flutter tarafındaki `test/widget_test.dart`'ın karşılıkları.

@Suite("HatGeom.clean: bozuk İBB güzergah adları")
struct HatGeomCleanTests {
    static let points = [
        Coordinate(latitude: 38.4, longitude: 27.0),
        Coordinate(latitude: 38.41, longitude: 27.05),
    ]

    @Test(arguments: [
        // KOD_ öneki atılır, yön addan düzeltilir (veride yanlışlıkla GİDİŞ geliyor).
        (ad: "kod_öksüzler - bergama dönüş", yon: "GİDİŞ", cleanAd: "öksüzler - bergama", cleanYon: "DÖNÜŞ"),
        // Yön kelimesi addan çıkar, yön korunur.
        (ad: "öksüzler - bergama gidiş", yon: "GİDİŞ", cleanAd: "öksüzler - bergama", cleanYon: "GİDİŞ"),
        // Parantezli yön eki atılır, aradaki parantez korunur.
        (ad: "MEVLANA (4. SANAYI SİT.) - BUCA (GİDİŞ)", yon: "GİDİŞ", cleanAd: "MEVLANA (4. SANAYI SİT.) - BUCA", cleanYon: "GİDİŞ"),
        // Yön kelimesi yoksa ad ve yön aynen kalır.
        (ad: "GEDİZ - IŞIKKENT", yon: "DÖNÜŞ", cleanAd: "GEDİZ - IŞIKKENT", cleanYon: "DÖNÜŞ"),
        // Yön kelimesi gidince sonda kalan tire de temizlenir.
        (ad: "  KOD Alfa - Beta - (dönüş) ", yon: "", cleanAd: "Alfa - Beta", cleanYon: "DÖNÜŞ"),
    ])
    func cleans(ad: String, yon: String, cleanAd: String, cleanYon: String) {
        let geom = HatGeom.clean(ad: ad, yon: yon, points: Self.points)
        #expect(geom.ad == cleanAd)
        #expect(geom.yon == cleanYon)
    }

    @Test("Bayrak verilmezse her nokta binilebilir")
    func defaultsToBoardable() {
        let geom = HatGeom(ad: "A", yon: "", points: Self.points)
        #expect(geom.boardable == [true, true])
        #expect(geom.isBoardable(at: 5))
    }
}

@Suite("HatOverrides: bölme ve çıkarma")
struct HatOverridesTests {
    private func route(_ groupID: String, _ name: String) -> DolmusRoute {
        DolmusRoute(id: "\(groupID)_x", groupID: groupID, groupName: "x", name: name, stops: [], stopsNorm: [], fee: 50)
    }

    @Test("Eşleştirme anahtarı: sadeleştir, harf/rakam dışını at")
    func key() {
        #expect(HatOverrides.key("KARŞIYAKA - EVKA 5") == "karsiyakaevka5")
    }

    @Test("M41: Buca/Mevlana satırları yeni hatta, gerisi ana hatta")
    func splitsM41() {
        let out = HatOverrides.applyRoutes([
            route("M41", "GEDİZ-OTOGAR-IŞIKKENT"),
            route("M41", "BUCA-MEVLANA-ADİLDEMİR"),
            route("M41", "MEVLANA-ÜLKÜ SİNEMASI"),
        ])
        #expect(out.map(\.groupID) == ["M41", "M41#buca", "M41#buca"])
        #expect(out.map(\.groupName) == ["x", "Mevlana - Buca", "Mevlana - Buca"])
        #expect(out[0].name == "GEDİZ-OTOGAR-IŞIKKENT")
    }

    @Test("Bölünmüş hat ücreti gerçek İBB kodundan çeker")
    func apiCode() {
        #expect(HatOverrides.apiCode(of: "M41#buca") == "M41")
        #expect(HatOverrides.apiCode(of: "M41") == "M41")
        #expect(HatOverrides.apiCode(of: "M07") == "M07")
    }

    @Test("M06: Körfez ücret satırı çıkarılır")
    func dropsM06Korfez() {
        let out = HatOverrides.applyRoutes([
            route("M06", "KARŞIYAKA-ONUR MAH."),
            route("M06", "KARŞIYAKA-KÖRFEZ MAHALLESİ"),
        ])
        #expect(out.map(\.name) == ["KARŞIYAKA-ONUR MAH."])
    }

    @Test("Geometriler: çıkarma, bölme ve ters çiftlerin takası")
    func appliesGeoms() {
        func geom(_ ad: String) -> HatGeom {
            HatGeom(ad: ad, yon: "GİDİŞ", points: HatGeomCleanTests.points)
        }
        let out = HatOverrides.applyGeoms([
            "M06": [geom("KARŞIYAKA - ONUR MAH."), geom("KARŞIYAKA - KÖRFEZ MAHALLESİ")],
            "M41": [geom("GEDİZ - IŞIKKENT"), geom("MEVLANA - BUCA")],
            "ÇEŞ01": [geom("eski yol")],
            "ÇEŞ02": [geom("otoyol")],
        ])
        #expect(out["M06"]?.map(\.ad) == ["KARŞIYAKA - ONUR MAH."])
        #expect(out["M41"]?.map(\.ad) == ["GEDİZ - IŞIKKENT"])
        #expect(out["M41#buca"]?.map(\.ad) == ["MEVLANA - BUCA"])
        #expect(out["ÇEŞ01"]?.map(\.ad) == ["otoyol"])
        #expect(out["ÇEŞ02"]?.map(\.ad) == ["eski yol"])
    }
}
