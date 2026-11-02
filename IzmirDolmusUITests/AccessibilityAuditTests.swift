import XCTest

/// Apple'ın erişilebilirlik denetimi (kontrast, dokunma alanı, Dynamic Type, açıklama)
/// bütün ana ekranlarda.
final class AccessibilityAuditTests: UITestCase {
    /// Testi düşüren denetimler: dokunma alanı, açıklama ve öğe türü. Kontrast,
    /// Dynamic Type ve kesik metin denetimleri bu uygulamada çok yanlış alarm veriyor
    /// (Liquid Glass ve yarı saydam sheet'lerin arkasındaki harita, harita üstü
    /// kontrollerde bilerek sınırlanan yazı boyutu, görünen metinden uzun VoiceOver
    /// etiketleri); onlar raporlanır, elle değerlendirilir (bkz. PLAN.md, Faz 8).
    static let enforced: XCUIAccessibilityAuditType = [.hitRegion, .sufficientElementDescription, .trait]

    /// Bizden olmayan ya da bilerek böyle bırakılan öğeler, gerekçesiyle.
    static func isExempt(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard let element = issue.element else {
            // Öğesi bulunamayan sorun: geçici ya da sistem görünümü.
            return true
        }
        let label = element.label
        // MapKit'in "Yasal" bağlantısı.
        if element.elementType == .link && label == "Yasal" { return true }
        // Dokunulmayan öğeler (ör. tarif şeridi tek öğe olarak okunur ama bir düğme değil).
        if issue.auditType == .hitRegion && [.other, .staticText, .image].contains(element.elementType) { return true }
        return false
    }

    /// Şu anki ekranı denetler. Zorunlu denetimlerde muaf olmayan sorun testi düşürür;
    /// diğerleri rapor olarak yazılır.
    func audit(_ screen: String, file: StaticString = #filePath, line: UInt = #line) throws {
        sleep(1)
        var failures: [String] = []
        try app.performAccessibilityAudit(for: .all) { issue in
            let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)' \($0.frame)" } ?? "-"
            let text = "\(issue.auditType.rawValue) | \(issue.compactDescription) | \(element)"
            if Self.enforced.contains(issue.auditType) && !Self.isExempt(issue) {
                failures.append(text)
            } else {
                print("AUDIT-INFO [\(screen)] \(text)")
            }
            return true
        }
        for failure in failures {
            print("AUDIT-FAIL [\(screen)] \(failure)")
        }
        XCTAssertTrue(failures.isEmpty, "\(screen): \(failures.joined(separator: "\n"))", file: file, line: line)
    }

    func walk() throws {
        waitForTabs()
        sleep(2)
        try audit("Anasayfa")
        tap(button("Yol tarifi: konum veya adres ara"))
        try audit("Yol tarifi")
        tap(app.navigationBars.buttons["Vazgeç"].firstMatch)

        tap(button(containing: "Etkinlikler"))
        try audit("Etkinlikler")
        tap(button(containing: "Test Konseri"))
        try audit("Etkinlik detayı")
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()

        tap(button("Favoriler"))
        try audit("Favoriler boş")
        tap(button("Ayarlar"))
        try audit("Ayarlar")

        tap(button("Harita"))
        try audit("Harita boş")
        tap(button("Önemli Noktalar"))
        try audit("Önemli Noktalar")
        tap(button("Kapat"))
        app.maps.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.2)
        expect(button(containing: "Hat listesi"))
        try audit("Harita nokta")
        tap(button(containing: "Hat listesi"))
        try audit("Yakın hatlar")
        tap(button(containing: "hattını aç"))
        expect(button("Hat Detayları, Ücretler ve Geri Bildirim"))
        try audit("Harita hat")
        tap(button("Hat Detayları, Ücretler ve Geri Bildirim"))
        try audit("Hat detayı")
        app.navigationBars.buttons.firstMatch.tap()
        tap(button("Geri"))
        tap(button("Geri"))

        tap(button("Anasayfa"))
        planTrip(from: "Bornova Metro", to: "Şirinyer")
        try audit("Harita tarif")
        tap(button("Adım adım"))
        try audit("Adım adım")
    }

    func testAuditDefaultTextSize() throws {
        launch()
        try walk()
    }

    func testAuditLargestTextSize() throws {
        launch(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        try walk()
    }
}
