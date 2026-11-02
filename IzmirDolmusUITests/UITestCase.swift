import CoreLocation
import XCTest

/// UI testlerinin ortak kısmı. Uygulama test modunda açılır (`-uiTesting`, bkz.
/// `AppEnvironment`): gerçek sunuculara gidilmez, simülatördeki asıl veriye dokunulmaz.
///
/// Elemanlar koordinatla değil erişilebilirlik etiketleriyle bulunur: test bir
/// akışı tamamlayabiliyorsa VoiceOver'ın göreceği ağaçta da o düğmeler vardır.
@MainActor
class UITestCase: XCTestCase {
    let app = XCUIApplication()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// Bornova Metro'nun yanı: yakın hatlar ve tarifler için.
    static let bornova = CLLocation(latitude: 38.4581, longitude: 27.2125)

    /// `arguments`: argüman alanından gelen başlangıç değerleri ya da sistem ayarları.
    /// Argüman alanı uygulamanın yazdığı değerin önüne geçer: tanıtım testinde bayrak
    /// verilmez (test alanı her açılışta boş başlar), yoksa "Başla" onu değiştiremez.
    func launch(onboarded: Bool = true, arguments: [String] = []) {
        continueAfterFailure = false
        XCUIDevice.shared.location = XCUILocation(location: Self.bornova)
        app.launchArguments = ["-uiTesting"] + (onboarded ? ["-onboarding_done", "YES"] : []) + arguments
        app.launch()
        allowLocationIfAsked()
    }

    /// Konum izni sorulduysa "kullanırken" izni verir. Sonraki koşularda sorulmaz.
    func allowLocationIfAsked(timeout: TimeInterval = 3) {
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: timeout) else { return }
        let allow = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "While Using", "Kullanırken")).firstMatch
        if allow.exists {
            allow.tap()
        }
    }

    // MARK: Sık kullanılanlar

    func button(_ label: String) -> XCUIElement {
        app.buttons[label].firstMatch
    }

    func button(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func text(containing text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    @discardableResult
    func tap(_ element: XCUIElement, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Bulunamadı: \(element)", file: file, line: line)
        element.tap()
        return element
    }

    func expect(_ element: XCUIElement, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Bulunamadı: \(element)", file: file, line: line)
    }

    /// Sekmeler yüklenene kadar bekler.
    func waitForTabs() {
        expect(button("Anasayfa"), timeout: 30)
    }

    /// Bir alana yazar. Odak geç gelebildiği için önce dokunur.
    func type(_ value: String, into field: XCUIElement) {
        tap(field)
        field.typeText(value)
    }

    /// Bir tarifi Nereden → Nereye sayfasından açar ve önerilen seçeneği seçer.
    func planTrip(from: String, to: String) {
        tap(button("Yol tarifi: konum veya adres ara"))
        type(from, into: app.textFields["Nereden"].firstMatch)
        tap(button(containing: from))
        type(to, into: app.textFields["Nereye"].firstMatch)
        tap(button(containing: to))
        tap(button("Rota bul"))
        tap(button(containing: "Önerilen"), timeout: 20)
    }
}
