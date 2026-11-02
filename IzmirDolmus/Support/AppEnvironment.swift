import DolmusCore
import Foundation

/// Store'ların varsayılan bağımlılıkları: gerçek sunucular, `UserDefaults.standard`
/// ve kalıcı klasörler.
///
/// UI testinde (`-uiTesting`, yalnızca Debug) hazır cevaplar ve her açılışta
/// temizlenen ayrı bir alan: testler gerçek sunuculara gitmez ve simülatördeki asıl
/// verine (favoriler, Ev/İş, önbellekler) dokunmaz. Yeniden açılışı deneyen test
/// `-uiTestingKeepData` ile alanı bırakır. Testin başlangıç değerleri
/// (`-onboarding_done YES` gibi) argüman alanından gelir; o alan her `UserDefaults`
/// örneğinde önceliklidir.
enum AppEnvironment {
    #if DEBUG
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
    private static let keepsUITestData = ProcessInfo.processInfo.arguments.contains("-uiTestingKeepData")
    #else
    static let isUITesting = false
    #endif

    static let defaults: UserDefaults = {
        #if DEBUG
        if isUITesting, let suite = UserDefaults(suiteName: uiTestSuite) {
            if !keepsUITestData {
                suite.removePersistentDomain(forName: uiTestSuite)
            }
            return suite
        }
        #endif
        return .standard
    }()

    /// Ücret ve etkinlik önbelleklerinin yeri.
    static func cacheFile(_ name: String, in directory: URL) -> URL {
        #if DEBUG
        if isUITesting {
            return uiTestDirectory.appending(path: name)
        }
        #endif
        return directory.appending(path: name)
    }

    nonisolated static let client: APIClient = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return APIClient(transport: UITestTransport())
        }
        #endif
        return APIClient()
    }()

    #if DEBUG
    private static let uiTestSuite = "com.izmirdolmus.app.uitest"
    private static let uiTestDirectory: URL = {
        let directory = URL.temporaryDirectory.appending(path: "uitest", directoryHint: .isDirectory)
        if !keepsUITestData {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }()
    #endif
}

#if DEBUG
/// UI testlerinin ağı: İBB'ye, GitHub'a, Open-Meteo'ya ve Google Form'a hiç gidilmez.
struct UITestTransport: HTTPTransport {
    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let body: String
        switch request.url?.host() {
        case "minibusguzergahlari.izmir.bel.tr":
            // Bilinmeyen kod için servis de 200 ve boş dizi döner.
            body = "[]"
        case "raw.githubusercontent.com":
            body = Self.events
        case "api.open-meteo.com":
            body = #"{"current": {"temperature_2m": 21.4, "weather_code": 1}}"#
        case "docs.google.com":
            body = "ok"
        default:
            throw URLError(.notConnectedToInternet)
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }

    /// Biri konumlu, biri konumsuz iki etkinlik; afişsiz, görsel için de ağa çıkılmaz.
    private static let events = """
    {"events": [
      {"id": "uitest-1", "source": "ibb", "title": "Test Konseri", "category": "Music",
       "start": "2099-06-01T20:30:00+03:00", "venue": "Bornova Metro", "lat": 38.4581, "lng": 27.2125},
      {"id": "uitest-2", "source": "ibb", "title": "Test Sergisi", "category": "SERGİ",
       "start": "2099-06-02T10:00:00+03:00", "venue": "Konak Sanat"}
    ]}
    """
}
#endif
