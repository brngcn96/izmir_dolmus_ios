import CoreLocation
import XCTest

/// Yolculuk modu: Live Activity, arka planda konumla takip, karttaki düğmeler,
/// yeniden açılışta sürdürme. Konum `XCUIDevice.shared.location` ile gerçek bir
/// tarifin noktaları boyunca taşınır; uygulama bu sırada arka plandadır.
final class JourneyModeTests: UITestCase {
    /// Ev (Bornova Metro) ve İş (Şirinyer), argüman alanından (`PlacePoint` dizi biçimi).
    static let places = ["-place_home_v1", "<5b22426f726e6f7661204d6574726f222c33382e343538312c32372e323132355d>", "-place_work_v1", "<5b22c59e6972696e796572222c33382e333935332c32372e313530305d>"]

    /// Bornova Metro → Şirinyer önerilen tarifinin bacakları. Planlayıcının çıktısı
    /// (veri değişirse yeniden üretilmeli; `DolmusCore` ile küçük bir betik).
    static let routeLegs: [(kind: String, points: [(Double, Double)])] = [
        ("walk", [(38.4581, 27.2125), (38.45876847141564, 27.212386800807135)]),
        ("ride", [(38.45876847141564, 27.212386800807135), (38.45872, 27.21192), (38.45873, 27.21028), (38.458, 27.20976), (38.45714, 27.20807), (38.45703, 27.20756), (38.45707, 27.20568), (38.45639, 27.20404), (38.45068, 27.19452), (38.44822, 27.19072), (38.44345, 27.18289), (38.44328, 27.18254), (38.44316, 27.18173), (38.44268, 27.18082), (38.44268, 27.18057), (38.44299, 27.18029), (38.44299, 27.18003), (38.44232, 27.1796), (38.44006, 27.1735), (38.43857, 27.17297), (38.43773, 27.17286), (38.43483, 27.17308), (38.43319, 27.17313), (38.43297, 27.17302), (38.43373, 27.1692), (38.43529, 27.16609), (38.4357, 27.1659), (38.43657, 27.1662), (38.43717, 27.16605), (38.43743, 27.16582), (38.43754, 27.1655), (38.43747, 27.16512), (38.43478, 27.16183), (38.43038, 27.15692), (38.42721, 27.15282), (38.42635, 27.15197), (38.42582, 27.15173), (38.42453, 27.15189), (38.42216, 27.15274), (38.4195, 27.1542), (38.41447, 27.15611), (38.41365, 27.15621), (38.41279, 27.15613), (38.41187, 27.15582), (38.41119, 27.15541), (38.41062, 27.15484), (38.41022, 27.15417), (38.40977, 27.15296), (38.40939, 27.15042), (38.40845, 27.14682), (38.40722, 27.14441), (38.40654, 27.14398), (38.40615, 27.14388), (38.40535, 27.14391), (38.40344, 27.14356), (38.40247, 27.14316), (38.40201, 27.1428), (38.40158, 27.14245), (38.39918, 27.13937), (38.39876, 27.139), (38.39767, 27.13843), (38.39649, 27.13813), (38.39605, 27.13787), (38.39567, 27.13744), (38.39492, 27.13576), (38.39488, 27.13524), (38.39511, 27.13486), (38.39521, 27.13482), (38.3953, 27.13501), (38.39464, 27.13639), (38.39406, 27.13999), (38.39351, 27.14154), (38.39284, 27.14941)]),
        ("walk", [(38.39284, 27.14941), (38.3953, 27.15)]),
    ]

    /// Bacakları adım adım konumlara böler: yürümede 30 m, dolmuşta 300 m, inişe son
    /// 1 km'de 60 m. Her konum hangi bacakta ve bacağın sonuna ne kaldığıyla.
    static func samples() -> [(lat: Double, lng: Double, leg: Int, remaining: Double)] {
        func meters(_ a: (Double, Double), _ b: (Double, Double)) -> Double {
            let dy = (b.0 - a.0) * 111_320, dx = (b.1 - a.1) * 111_320 * cos(a.0 * .pi / 180)
            return (dx * dx + dy * dy).squareRoot()
        }
        var result: [(Double, Double, Int, Double)] = []
        for (index, leg) in routeLegs.enumerated() {
            let points = leg.points
            var cumulative = [0.0]
            for i in 1..<points.count {
                cumulative.append(cumulative[i - 1] + meters(points[i - 1], points[i]))
            }
            let total = cumulative.last!
            var along = 0.0
            while true {
                let i = max((cumulative.firstIndex { $0 > along } ?? cumulative.count) - 1, 0)
                let j = min(i + 1, points.count - 1)
                let segment = cumulative[j] - cumulative[i]
                let t = segment > 0 ? (along - cumulative[i]) / segment : 0
                result.append((points[i].0 + t * (points[j].0 - points[i].0), points[i].1 + t * (points[j].1 - points[i].1), index, total - along))
                if along >= total { break }
                along = min(along + (leg.kind == "walk" ? 30 : (total - along > 1_000 ? 300 : 60)), total)
            }
        }
        return result
    }

    // MARK: Yardımcılar

    /// Ev → İş tarifini açıp yolculuğu başlatır.
    func startJourney() {
        launch(arguments: Self.places)
        waitForTabs()
        openLink("izmirdolmus://trip?direction=toWork")
        tap(button(containing: "Önerilen"), timeout: 20)
        tap(button("Yolculuğu başlat"))
    }

    func openNotificationCenter() {
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.005))
            .press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.75)))
        sleep(2)
    }

    func closeNotificationCenter() {
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
            .press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        sleep(1)
    }

    func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func cardText(_ text: String) -> XCUIElement {
        springboard.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Bildirim merkezinde kartta `text` var mı.
    func cardShows(_ text: String) -> Bool {
        openNotificationCenter()
        let found = cardText(text).waitForExistence(timeout: 4)
        closeNotificationCenter()
        return found
    }

    // MARK: Testler

    /// Arka planda konum güzergah boyunca ilerler: kart kendiliğinden ilerler, inişe
    /// yaklaşınca uyarır, varınca yolculuk kapanır.
    func testTrackingAlongRoute() {
        startJourney()
        XCUIDevice.shared.press(.home)
        sleep(2)
        var checkedRide = false, checkedApproach = false, checkedWalk = false
        for sample in Self.samples() {
            XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: sample.lat, longitude: sample.lng))
            usleep(600_000)
            if sample.leg == 1, !checkedRide, sample.remaining < 11_000 {
                checkedRide = true
                XCTAssertTrue(cardShows("dolmuşu"), "dolmuşta kart hattı göstermeli")
            }
            if sample.leg == 1, !checkedApproach, sample.remaining < 300 {
                checkedApproach = true
                XCTAssertTrue(cardShows("Hazırlan"), "inişe yaklaşınca uyarmalı")
            }
            if sample.leg == 2, !checkedWalk, sample.remaining < 250 {
                checkedWalk = true
                XCTAssertTrue(cardShows("Varışa yürü"), "inince varışa yürümeli")
            }
        }
        sleep(2)
        XCTAssertTrue(cardShows("Vardın"))
        app.activate()
        expect(button("Yolculuğu başlat"))
    }

    /// Yolculuk sürerken başka bir tarif: bantta o tarifin başlatma düğmesi ve süren
    /// yolculuğun biteceği notu çıkar, süren yolculuğun kontrolleri çıkmaz. Anasayfa'da
    /// süren yolculuğun kartı var; oradan bitirilir.
    func testOtherTripWhileJourneyActive() {
        startJourney()
        expect(button("Bitir"))
        // Başka bir tarif: uçları yer değiştirip yeniden planla.
        tap(button(containing: "nereye"))
        tap(button("Yer değiştir"))
        tap(button("Rota bul"))
        tap(button(containing: "Önerilen"), timeout: 20)
        expect(button("Yolculuğu başlat"))
        expect(text(containing: "süren yolculuk"))
        XCTAssertFalse(button("Sonraki adım").exists, "başka tarifte süren yolculuğun kontrolleri olmamalı")

        tap(button("Geri"))
        expect(element(containing: "Süren yolculuk"))
        tap(button("Bitir"))
        XCTAssertFalse(element(containing: "Süren yolculuk").waitForExistence(timeout: 3), "bitirince kart kalkmalı")
    }

    /// Karttaki düğmeler uygulamayı açmadan çalışır; uygulama kapanıp açılınca yolculuk
    /// sürer; karta dokununca haritada açılır; karttaki "Bitir" kapatır.
    func testCardButtonsAndResume() {
        startJourney()
        XCUIDevice.shared.press(.home)
        sleep(2)
        openNotificationCenter()
        let next = springboard.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sonraki adım")).firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        XCTAssertTrue(cardText("dolmuşu").waitForExistence(timeout: 5), "karttan ilerletince dolmuş adımı")
        closeNotificationCenter()

        // Uygulama kapanır, kart kalır. Yeniden açılışta test alanı silinmesin: kayıtlı
        // yolculuk orada.
        app.terminate()
        app.launchArguments.append("-uiTestingKeepData")
        app.launch()
        waitForTabs()
        expect(element(containing: "Süren yolculuk"))
        XCUIDevice.shared.press(.home)
        sleep(2)
        openNotificationCenter()
        let card = cardText("dolmuşu")
        XCTAssertTrue(card.waitForExistence(timeout: 5), "yeniden açılıştan sonra kart duruyor")
        card.tap()
        expect(button("Bitir"))
        expect(text(containing: "dolmuşu"))

        XCUIDevice.shared.press(.home)
        sleep(2)
        openNotificationCenter()
        let end = springboard.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bitir")).firstMatch
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        sleep(2)
        XCTAssertFalse(cardText("dolmuşu").exists, "karttan bitirince kart kalkmalı")
        closeNotificationCenter()
        app.activate()
        expect(button("Yolculuğu başlat"))
    }
}
