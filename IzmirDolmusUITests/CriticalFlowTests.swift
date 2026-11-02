import XCTest

/// Uygulamanın ana akışları, baştan sona.
final class CriticalFlowTests: UITestCase {
    func testOnboarding() {
        launch(onboarded: false)
        tap(button("İleri"), timeout: 20)
        tap(button("İleri"))
        tap(button("Başla"))
        waitForTabs()
    }

    func testFindHatAndFavorite() {
        launch()
        waitForTabs()
        tap(button("Favoriler"))
        expect(text(containing: "Henüz favori hattın yok"))

        tap(button("Hatlar"))
        let search = app.searchFields.firstMatch
        type("Buca", into: search)
        tap(app.cells.containing(.staticText, identifier: "Buca - Bornova").firstMatch)
        tap(button("Favorilere ekle"))
        expect(button("Favorilerden çıkar"))

        // Favoriler sekmesinde görünür; oradan açılıp çıkarılır.
        tap(button("Favoriler"))
        tap(button(containing: "Buca - Bornova"))
        tap(button("Favorilerden çıkar"))
        app.navigationBars.buttons.firstMatch.tap()
        expect(text(containing: "Henüz favori hattın yok"))
    }

    func testTripPlanning() {
        launch()
        waitForTabs()
        planTrip(from: "Bornova Metro", to: "Şirinyer")
        tap(button("Adım adım"))
        expect(text(containing: "dolmuşuna bin"))
        expect(button(containing: "Haritalar'da aç"))
    }

    func testEventsAndShowOnMap() {
        launch()
        waitForTabs()
        tap(button(containing: "Etkinlikler"))
        tap(button(containing: "Test Sergisi"))
        expect(text(containing: "konum bilgisi bulunmuyor"))
        app.navigationBars.buttons.firstMatch.tap()
        tap(button(containing: "Test Konseri"))
        tap(button("Haritada göster"))
        // Harita mekanla açılır; "Geri" geldiği sekmeye (Anasayfa) döndürür.
        expect(button(containing: "Hat listesi"))
        tap(button("Geri"))
        expect(button(containing: "Etkinlikler"))
    }

    /// Önemli Noktalar → tür → yer: liste ana aktörün dışında hesaplanıp gelir,
    /// seçilen yer haritada açılır.
    func testCategoryPlaces() {
        launch()
        waitForTabs()
        tap(button("Önemli Noktalar"))
        tap(button(containing: "Hastaneler"))
        let firstPlace = app.collectionViews.buttons.firstMatch
        expect(firstPlace)
        firstPlace.tap()
        expect(button(containing: "Hat listesi"))
    }

    func testMapLongPress() {
        launch()
        waitForTabs()
        tap(button("Harita"))
        let map = app.maps.firstMatch
        expect(map)
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.2)
        tap(button(containing: "Hat listesi"))
        tap(button(containing: "hattını aç"))
        expect(button("Hat Detayları, Ücretler ve Geri Bildirim"))
        tap(button("Geri"))
        expect(button(containing: "Hat listesi"))
    }

    func testFeedback() {
        launch()
        waitForTabs()
        tap(button("Hatlar"))
        type("Buca", into: app.searchFields.firstMatch)
        tap(app.cells.containing(.staticText, identifier: "Buca - Bornova").firstMatch)
        let list = app.collectionViews.firstMatch
        let yes = button(containing: "Evet")
        while !yes.exists || !yes.isHittable {
            list.swipeUp()
        }
        yes.tap()
        tap(button(containing: "Geri bildirimi gönder"))
        expect(text(containing: "Teşekkürler"))
    }

    /// Sistemin değerlendirme kartındaki "Şimdi değil" (Debug'da kart her istekte çıkar).
    var reviewNotNow: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label IN %@", ["Not Now", "Şimdi Değil"])).firstMatch
    }

    /// Koşullar hazırken (önceki bir gün başladı, iki başarılı tarif) yol tarifinden
    /// sonra haritadan çıkınca değerlendirme kartı istenir.
    func testReviewPromptAfterTrip() {
        launch(arguments: ["-review_first_day", "2026-1-1", "-review_trip_ok", "5"])
        waitForTabs()
        planTrip(from: "Bornova Metro", to: "Şirinyer")
        tap(button("Geri"))
        tap(reviewNotNow)
    }

    /// İlk kullanım gününde sorulmaz (tek günlük deneyenlere sorma).
    func testNoReviewPromptOnFirstDay() {
        launch()
        waitForTabs()
        planTrip(from: "Bornova Metro", to: "Şirinyer")
        tap(button("Geri"))
        XCTAssertFalse(reviewNotNow.waitForExistence(timeout: 4))
    }

    func testDeepLinkOpensHat() {
        launch()
        waitForTabs()
        app.open(URL(string: "izmirdolmus://hat/M19")!)
        // Sistem "Open in …?" diye sorar; widget dokunuşunda bu onay çıkmıyor.
        let open = springboard.buttons["Open"].firstMatch
        if open.waitForExistence(timeout: 3) {
            open.tap()
        }
        expect(button("Favorilere ekle"))
    }
}
