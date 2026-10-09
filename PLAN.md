# İzmir Dolmuş iOS — Plan

Plan tarihi: 2026-10-08 · Durum: Faz 0 bitti (commit onayını bekliyor) · Faz 1 sürüyor — iskelet ve portlar hazır, Flutter ile eşleşme doğrulandı, sıra S1.1–S1.5'te (sende)

Hedef: Android'de yayında olan Flutter uygulamasının (v1.0.6) özellik eşiti bir
native iOS sürümünü SwiftUI ile yazıp App Store'da yayınlamak; bunu yaparken
SwiftUI, Swift 6 eşzamanlılığı ve modern ağ katmanını öğrenmek.

Bu repo yalnızca iOS uygulamasıdır. Android (Flutter) uygulaması ayrı bir
repo'da durur (`izmir_dolmus`); bu repo ona bağımlı olmadan klonlanıp derlenir.

## Kararlar

| Konu | Karar | Gerekçe |
|---|---|---|
| Repo | iOS ayrı repo (`izmir_dolmus_ios`) | Flutter repo'suna iOS dosyası girmez; bu repo tek başına derlenir. |
| Minimum iOS | **26.0** | Liquid Glass API'lerinin tamamı (`glassEffect`, `GlassEffectContainer`, `tabBarMinimizeBehavior`, `tabViewBottomAccessory`…) 26.0'da geldi. NavigationStack (16), `@Observable` (17), MapKit-SwiftUI (17) ve yeni `Tab` API'si (18) bu sürümde olgun; `#available` dallanması gerekmiyor. iOS 27'ye özel SwiftUI eklemeleri (belge API'leri, yeniden sıralama, araç çubuğu taşması) bu uygulamaya lazım değil. Bedeli: iPhone 11 ve sonrası; iOS 18'de kalan cihazlar kapsam dışı. |
| Araçlar | Xcode 27, iOS 27 SDK, Swift 6.4 derleyici, **Swift 6 dil modu** | Xcode 27 şablonu dil sürümünü hâlâ 5 açıyor; S0.1'de elle 6 yapılır. |
| Eşzamanlılık | Uygulama hedefi: varsayılan izolasyon `MainActor` + Approachable Concurrency. `DolmusCore`: izolasyonsuz, `Sendable` değer tipleri | UI kodu ana aktörde, ağır iş (JSON, planlayıcı) açıkça `@concurrent` ile dışarıda. |
| Harita | **MapKit** (SwiftUI `Map`) | Bağımlılık ve anahtar yok, sistem görünümüyle uyumlu. Çizgiye dokunma ve POI seyreltme kendi kodumuzla. |
| Mimari | **`@Observable` store + Router** | ViewModel yalnızca gerçek ekran mantığı olan yerde (Harita, Yol tarifi). Router, UIKit'teki Coordinator'ın karşılığı. |
| Modüller | Uygulama hedefi + yerel Swift paketi `DolmusCore` | Model, veri, arama, planlayıcı ve ağ kodu Mac'te `swift test` ile saniyeler içinde doğrulanır; UI/domain ayrımını derleyici korur. |
| Veri | Bu repo'da kopya: `DolmusCore/Sources/DolmusCore/Resources/` | Tek kaynak Flutter repo'sundaki `assets/data/`. Kopya `Scripts/sync-data.sh` ile güncellenir, elle düzenlenmez; geldiği commit `DATA_SOURCE` dosyasında. |
| Kalıcılık | UserDefaults (favori, son aramalar, Ev/İş, bayraklar) + dosya önbelleği (ücret, etkinlik) | SwiftData'ya değecek hacimde veri yok. |
| Ağ | `URLSession` async/await, 3. parti kütüphane yok | |
| Reklam ve analitik | En sonda ayrı, atlanabilir faz (Faz 9) | |
| Öğrenme düzeni | Dengeli: faz başına 4-6 kilit parçayı sen yazarsın | |

Varsayımlar (itirazın varsa değiştiririz): yalnızca iPhone, yalnızca Türkçe,
açık + koyu mod.

## Proje yapısı

```
izmir_dolmus_ios/
├─ IzmirDolmus.xcodeproj
├─ IzmirDolmus/            uygulama hedefi (SwiftUI ekranlar, store'lar, Router)
│  ├─ Assets.xcassets      marka renkleri, ikon
│  ├─ Fonts/               Figtree
│  └─ Support/
├─ DolmusCore/             yerel paket (model, veri, arama, geometri, planlayıcı, ağ)
│  ├─ Sources/DolmusCore/Resources/   veri dosyaları (eşitlenen kopya)
│  └─ Tests/DolmusCoreTests/
├─ Scripts/sync-data.sh    veriyi Flutter repo'sundan eşitler
├─ DATA_SOURCE             verinin geldiği Flutter commit'i
└─ PLAN.md
```

## Flutter repo'suyla ilişki

- **Veri:** Flutter tarafında `assets/data/` değişince burada
  `Scripts/sync-data.sh` çalıştırılır (varsayılan yol `../izmir_dolmus`), testler
  koşulur, sonuç commit edilir.
- **Altın dosyalar:** portların Flutter ile aynı sonucu verdiğini kanıtlayan
  beklenen çıktılar bu repo'da durur (`DolmusCore/Tests/DolmusCoreTests/Golden/`,
  elle düzenlenmez). `Scripts/export-golden.sh`, dışa aktarım testini
  (`Scripts/golden_export_test.dart`) Flutter repo'sunun `test/` klasörüne geçici
  olarak kopyalar, `flutter test` ile çalıştırır ve siler; Flutter repo'suna
  kalıcı dosya eklenmez. Çıktının geldiği commit `Golden/SOURCE`'ta. Flutter'da
  veri ya da veri/arama kodu değişince: `sync-data.sh` → `export-golden.sh` →
  `swift test`.
- **Kod:** paylaşılmaz. Düzeltme kuralları (`hat_overrides`, `board_overrides`)
  iki repo'da ayrı durur; sapmayı altın dosya testleri yakalar.

## Çalışma düzeni (her faz)

1. **Açılış:** fazın hedefi, "bitti" tanımı ve senin yazacağın parçaların listesi.
2. **İskelet:** portları ve tekrarlayan kodu ben yazar, derler, testleri
   çalıştırırım. Senin yazacağın yerlere `// ✍️ SEN (S2.1): …` işareti bırakırım.
   İşaretli yer derlenen bir yer tutucudur; uygulama her an çalışır durumda kalır.
3. **Sen yaz:** kodu sohbette veririm (dosya, işaret, kısa "neden böyle").
   Yapıştırmadan yazar, çalıştırır, "yazdım" dersin.
4. **Geri bildirim:** dosyanı okur, derler ve test ederim; farkları ve varsa
   daha iyi yazımı söylerim.
5. **Konu anlatımı (faz sonu):** kavramlar UIKit karşılıklarıyla, bu fazda
   yazdığın kodun gerekçeleri, sık yapılan hatalar, 3-5 kontrol sorusu. Ardından commit.

Süreler senin tarafındaki kaba tahmindir (toplam 40-50 saat civarı); Faz 1'den
sonra gerçek hıza göre güncellenir.

## Fazlar

### [x] Faz 0 — Kurulum ve iskelet (~1-2 saat)
- **Çıktı:** simülatörde açılan boş uygulama; Swift 6 dil modu, iOS 26 hedefi;
  `DolmusCore` bağlı; veri dosyaları, Figtree ve marka renkleri projede.
- **Sen:** S0.1 projeyi Xcode'da açıp Swift Language Version'ı 6 yapmak, Team
  seçmek, simülatörde çalıştırmak · S0.2 ilk `View` (`RootView`) + `#Preview` ·
  S0.3 `@main` `App` + `WindowGroup`.
- **Ben (yapıldı):** repo (`git init`, henüz commit yok), Xcode projesi
  (`com.izmirdolmus.app`, iOS 26.0, yalnızca iPhone, geliştirme dili Türkçe),
  `DolmusCore` paketi + veri kaynakları + ilk test, `Scripts/sync-data.sh`,
  `AccentColor`/`BrandSoft` (açık/koyu), uygulama ikonu (düz PNG), `UIAppFonts`
  ile Figtree kaydı, geçici `SetupCheck` yardımcı kodu.
- Proje dosyası Xcode sihirbazıyla değil, Xcode 27 "iOS App (SwiftUI)" şablonunun
  ayarları okunarak elle yazıldı. Şablondaki gibi Swift 5 modunda bırakıldı;
  6'ya geçiş S0.1'in işi. Test hedefi yok: domain testleri pakette, UI testi
  hedefi Faz 8'de Xcode'dan eklenecek.
- **Konu anlatımı:** UIKit'ten SwiftUI'a zihin haritası — AppDelegate/SceneDelegate
  → `App`/`Scene`; `UIView` (kalıcı nesne) → `View` (geçici tarif); `body`'nin
  yeniden hesaplanması ve kimlik; şablondaki eşzamanlılık ayarlarının anlamı.
- **Bitti sayılır:** temiz derleme, simülatörde açılış, `swift test` yeşil.
- **Sonuç (2026-10-08):** üçü de sağlandı. Team seçilmedi (`DEVELOPMENT_TEAM`
  boş): simülatör için gerekmiyor, gerçek cihaza kurulumdan önce seçilecek.

### [ ] Faz 1 — Veri katmanı: Swift 6 ile domain (~3-4 saat)
- **Çıktı:** dört JSON ana aktör dışında yüklenir; bölme/çıkarma kuralları
  uygulanmış hatlar düz bir listede görünür; sonucun Flutter ile aynı olduğu testle kanıtlı.
- **Ben (yapıldı):** modeller (`Coordinate`, `DolmusRoute`, `DolmusHat`,
  `HatGeom`, `PlacePoint`, `Landmark`), güzergah adı temizliği (`HatGeom.clean`),
  `HatOverrides`/`BoardOverrides` portu, `DolmusData` (hatlar, ilçe grupları,
  güzergahlar, hat ve yer araması, yer türü), liste satırı (`HatRow`); birim
  testleri, **altın dosya testleri** (`GoldenTests`) ve onları Flutter kodundan
  üreten `Scripts/export-golden.sh`.
- **Sen:** S1.1 dizi biçimli JSON için özel `Decodable`: `Coordinate`,
  `PlacePoint` (`["Konak · Konak", 38.41, 27.12]`), `Landmark` · S1.2 `trNorm` +
  Swift Testing ile parametreli test · S1.3 `@concurrent` yükleyici · S1.4
  `@Observable` `DataStore` + yükleme durumu `enum`'u · S1.5 ilk `List` + `.task`.
- **Doğrulama (2026-10-08):** beş parça geçici olarak yerine konup sırayla
  denendi. Hepsi yerindeyken 27 test yeşil; altın dosyalarda 410 hat, 846
  güzergah, 30 ilçe, 76 hat sorgusu, 172 yer sorgusu ve 40.493 yerin türü Flutter
  ile birebir. Uygulama simülatörde listeyi, yükleniyor ve hata durumlarını
  gösterdi; yükleme ~0,5 sn (debug), ana thread dışında. Yer tutucularla 22 test
  kırmızıdır; parçalar yazıldıkça yeşile döner (S1.1 → 6, S1.2 → 14, S1.3 → 27).
- **Port notları:**
  - Dart'ın `List.sort`'u 33 elemandan uzun listelerde kararsızdır (eşit
    elemanların sırası değişebilir), Swift'inki kararlı. Uygulamada yer araması
    hep haritanın odağıyla çağrıldığı için eşitlik pratikte çıkmıyor; altın
    dosyalardaki yer sorguları da hep bir odakla (`near`) üretilir.
  - Dart düzenli ifadelerinde `\b` yalnızca ASCII'yi kelime sayar ve büyük/küçük
    harf eşlemesi "ı"/"İ"yi "i"ye bağlamaz; yer türü çıkarımı
    (`PlaceClassifier`) bu kuralları elle uygular.
  - Dart dizgi işlemleri UTF-16 birimiyle, Swift'inkiler yazı birimi ve Unicode
    eşdeğerliğiyle çalışır; veride birleşen işaretli adlar olduğu için arama ve
    sıralama `DartText.swift`'teki bayt düzeyindeki yardımcılarla yapılır.
- **Faz sonunda silinecek:** `DolmusCore/Sources/DolmusCore/Unwritten.swift` (yer
  tutucu hatası), `IzmirDolmus/Support/SetupCheck.swift` ve `RootView`'daki
  `CheckRow` (S1.5 ile kullanılmaz olur).
- **Konu anlatımı:** Swift 6 eşzamanlılık modeli (izolasyon alanları, MainActor
  varsayılanı, `nonisolated`, `@concurrent`, `Sendable`, veri yarışı güvenliği;
  GCD karşılıkları), değer tipleriyle modelleme, `Codable` derinlemesine, Swift Testing.
- **Bitti sayılır:** altın dosyalar dahil testler yeşil; ana thread'de JSON çözme yok.

### [ ] Faz 2 — Gezinme iskeleti: Liquid Glass tab bar + NavigationStack + Router (~4-5 saat)
- **Çıktı:** cam tab bar'lı sekmeli uygulama; Hatlar (ilçe grupları + anlık arama)
  → Hat detayı (temel); sekme başına bağımsız gezinme yığını; alt sayfa örneği.
- **Karar noktası:** sekme düzeni — (A) Android'deki 5 sekme, (B) 4 sekme + ayrık
  arama düğmesi olarak Hatlar. İkisini simülatörde deneyip seçeceksin.
- **Sen:** S2.1 `enum Route: Hashable` + `NavigationStack(path:)` +
  `navigationDestination(for:)` · S2.2 `@Observable` `Router` (seçili sekme + sekme
  başına yol) ve `@Environment` ile dağıtımı · S2.3 `TabView` + `Tab` API + arama
  rolü + `tabBarMinimizeBehavior` · S2.4 `.searchable` + açılır-kapanır ilçe
  bölümleri · S2.5 `.sheet(item:)` + `presentationDetents`.
- **Konu anlatımı:** NavigationStack derinlemesine (değer tabanlı gezinme, yol
  durumu, hedeflerin nerede tanımlanacağı, köke dönme, sheet mi push mu, sık
  hatalar), TabView ve Liquid Glass davranışı, UINavigationController/Coordinator karşılıkları.
- **Bitti sayılır:** liste → detay → geri, sekme değiştirme ve köke dönme tutarlı;
  Router'dan programatik geçiş çalışır.

### [ ] Faz 3 — Durum yönetimi ve tasarım sistemi (~4-5 saat)
- **Çıktı:** Favoriler, Ayarlar (Ev/İş, son aramalar), tam Hat detayı (ücret
  bölgeleri, kilit nokta çipleri, oy/not); tema jetonları, Figtree, koyu mod, Dynamic Type.
- **Sen:** S3.1 `UserStore` (favoriler, UserDefaults kalıcılığı) · S3.2 `@Bindable`/
  `Binding` ile Ev/İş düzenleme · S3.3 `Layout` protokolüyle `FlowLayout` · S3.4
  `ViewModifier` + `ButtonStyle` ile kart ve buton stilleri · S3.5 `glassEffect` +
  `GlassEffectContainer` ile yüzen bir kontrol.
- **Konu anlatımı:** SwiftUI veri akışı (`@State`, `@Binding`, `@Observable`,
  `@Bindable`, `@Environment`), view kimliği ve ömrü, özel `Layout`, stiller,
  Liquid Glass'ın nerede kullanılıp nerede kullanılmayacağı.
- **Bitti sayılır:** favori değişikliği tüm ekranlara anında yansır ve yeniden
  açılışta kalır; koyu modda ve en büyük yazı boyutunda ekranlar bozulmaz.

### [ ] Faz 4 — Modern ağ katmanı (~4-5 saat)
- **Çıktı:** İBB'den ücret tazeleme (yaklaşık 400 hat kodu, en çok 6 eşzamanlı
  istek, ilerleme, iptal); Etkinlikler (liste, filtreler, detay, 6 saatlik
  önbellek); hava durumu; geri bildirim gönderimi.
- **Sen:** S4.1 `Endpoint` + `APIClient.send` (durum kodu, decode, tipli hata) ·
  S4.2 `withTaskGroup` ile sınırlı eşzamanlı ücret tazeleme · S4.3 `.task` +
  `.refreshable` + yükleniyor/boş/hata durumları · S4.4 `AsyncImage` ile etkinlik
  kartı · S4.5 sahte taşıyıcıyla ağ testi.
- **Konu anlatımı:** yapılandırılmış eşzamanlılık (`async let`, `TaskGroup`, iptal,
  `.task` ömrü), ağ katmanı tasarımı (uç nokta, hata tipleri, zaman aşımı,
  önbellek), completion handler/OperationQueue karşılıkları.
- **Bitti sayılır:** uçak modunda önbellekle çalışır; tazeleme iptal edilebilir;
  ağ testleri gerçek sunucuya gitmeden yeşil.

### [ ] Faz 5 — Harita I: MapKit (~5-6 saat)
- **İlk iş (risk kontrolü):** Bergama, Tire, Çeşme gibi dış ilçelerde Apple
  Haritalar altlığının yeterliliğine birlikte bakmak.
- **Çıktı:** hat güzergahı çizimi (gidiş/dönüş/varyant), kameranın İzmir'e
  sınırlanması, konumum, uzun basınca "Seçilen nokta" + yakın hatlar (renkli
  çizgiler ve açıklama), çizgiye dokununca hat tanıma, yakınlaştıkça durak/POI
  işaretleri, alt panel; diğer sekmelerden "Haritada göster".
- **Sen:** S5.1 `Map(position:)` + `MapPolyline` + kamerayı sığdırma · S5.2
  `MapReader` ile uzun basma → koordinat → yakın hatlar · S5.3
  `CLLocationUpdate.liveUpdates()` + izin akışı · S5.4 `onMapCameraChange` +
  debounce ile görünür alandaki POI'ler · S5.5 Router üzerinden "Haritada göster"
  · S5.6 detent'li alt panel.
- **Konu anlatımı:** MapKit for SwiftUI (içerik oluşturucu, `MapCameraPosition`,
  `MapReader`, performans), CoreLocation'ın async API'leri, jestler;
  `UIViewRepresentable` ile `MKMapView`'a ne zaman inilir.
- **Bitti sayılır:** Flutter'daki harita senaryoları çalışır; kaydırma akıcı.

### [ ] Faz 6 — Yol tarifi (~4-5 saat)
- **Çıktı:** Nereden → Nereye ekranı (otomatik tamamlama, takas, konumum),
  planlayıcı (aktarmasız + 1 aktarma), seçenek listesi, adım adım tarif, haritada
  yürüme (kesik) ve dolmuş (renkli) bacakları, yürüme bacağını Apple Haritalar'da açma.
- **Ben:** `journey_planner.dart` + `walk_barriers.dart` portu; örnek nokta
  çiftleri için Flutter çıktılarıyla altın dosya testleri.
- **Sen:** S6.1 `TripPlannerModel` · S6.2 `.task(id:)` ile debounce'lu otomatik
  tamamlama · S6.3 planlayıcıyı ana aktör dışında çalıştırma · S6.4 yolculuk kartı
  ve adım listesi (`enum` + `switch`) · S6.5 `MKMapItem` ile Haritalar'da açma.
- **Konu anlatımı:** CPU işi için aktör mü `Sendable` değer tipi mi, `Task` iptali
  ve debounce, ViewModel'in gerçekten gerektiği yer, `@FocusState`.
- **Bitti sayılır:** aynı uçlar için iOS ve Android aynı rotaları aynı sırada
  verir (testle); planlama sırasında arayüz donmaz.

### [ ] Faz 7 — Anasayfa, onboarding, açılış animasyonu (~4-5 saat)
- **Çıktı:** Anasayfa (hava durumu, arama girişi, Ev/İş/Önemli Noktalar çipleri,
  yakınındaki hatlar mini haritası, etkinlik girişi, son aramalar), ilk açılış
  tanıtımı (bağlam içinde konum izni), kayan dolmuş animasyonu; Icon Composer ile
  katmanlı (Liquid Glass) uygulama ikonu — şimdilik Android'deki düz ikon kullanılıyor.
- **Sen:** S7.1 `KeyframeAnimator`/`PhaseAnimator` ile açılış animasyonu · S7.2
  sayfalı onboarding · S7.3 anasayfa bileşimi (mini harita kartı, yatay çipler) ·
  S7.4 `matchedTransitionSource` + zoom geçişi · S7.5 `@AppStorage` bayrağı.
- **Konu anlatımı:** animasyon sistemi (örtük/açık, geçişler, faz ve anahtar kare
  animasyonları), kaydırma API'leri, view bileşimi.
- **Bitti sayılır:** reklam/analitik dışında Android ile özellik eşitliği.
- **Erken yayın noktası:** buradan Faz 8 + Faz 10 ile reklamsız yayınlanabilir.

### [ ] Faz 8 — Kalite: erişilebilirlik, performans, testler (~3-4 saat)
- **Çıktı:** VoiceOver ve Dynamic Type uyumu, gereksiz yeniden çizimlerin
  temizliği, kritik akış UI testi, değerlendirme isteği; isteğe bağlı olarak
  izmirdolmus.com hat sayfalarından uygulamaya Universal Link.
- **Sen:** S8.1 erişilebilirlik etiketleri · S8.2 `Self._printChanges()` ile
  yeniden çizim avı · S8.3 bir akış için XCUITest · S8.4 `onOpenURL` → Router ·
  S8.5 `requestReview` kuralları.
- **Konu anlatımı:** SwiftUI performans modeli (bağımlılık takibi, kimlik,
  Instruments), erişilebilirlik, derin bağlantılar.
- **Bitti sayılır:** harita ve listeler takılmasız; VoiceOver ile ana akışlar
  tamamlanabilir; testler yeşil.

### [ ] Faz 9 — Analitik ve reklam (isteğe bağlı, ~3-4 saat)
- **Ön koşul (sende):** Firebase'de iOS uygulaması (`GoogleService-Info.plist`),
  AdMob'da iOS uygulaması ve reklam birimleri.
- **Çıktı:** Android'dekiyle aynı adlarla analitik olayları; banner, App Open ve
  geçiş reklamı (aynı kurallar: günde 1, ilk oturumda yok); ATT izin akışı, rıza
  penceresi, gizlilik manifesti.
- **Karar noktası:** banner'ın yüzen cam tab bar ile çakışmayan yerleşimi.
- **Sen:** S9.1 `Analytics` cephesi · S9.2 banner için `UIViewRepresentable`
  sarmalayıcı · S9.3 ATT akışı · S9.4 `scenePhase` ile App Open tetikleme.
- **Konu anlatımı:** UIKit ↔ SwiftUI köprüleme, Swift 6 altında `Sendable`
  olmayan 3. parti SDK'lar, ATT ve gizlilik kuralları.
- **Bitti sayılır:** test reklamları doğru anlarda görünür; izin reddinde
  uygulama sorunsuz çalışır.

### [ ] Faz 10 — Yayın (~3-4 saat + inceleme süresi)
- **Çıktı:** imzalama, App Store Connect kaydı, gizlilik etiketleri, ekran
  görüntüleri, TestFlight, incelemeye gönderim; web sitesine App Store bağlantısı;
  Figtree (SIL OFL) lisans bildirimi.
- **Konu anlatımı:** imzalama ve provisioning, App Review'da sık ret nedenleri
  (konum izni metni, ATT), sürümleme, aşamalı yayın, yayın sonrası izleme.
- **Bitti sayılır:** uygulama App Store'da.

## Flutter → iOS karşılıkları

Sol sütundaki dosyalar Flutter repo'sunda, `lib/` altındadır.

| Flutter | iOS | Faz |
|---|---|---|
| `models.dart` | `DolmusCore` modelleri (`Sendable` struct) | 1 |
| `repository.dart` | yükleyici, hat/yer araması, POI ızgarası, yakın hat geometrisi | 1, 5 |
| `hat_overrides.dart`, `board_overrides.dart` | `DolmusCore` düzeltme kuralları | 1 |
| `main.dart` (sekmeler, harita sinyalleri) | `App`, kök `TabView`, `Router` | 2 |
| `screens/search_screen.dart`, `hat_detail.dart` | Hatlar, Hat detayı | 2-3 |
| `user_prefs.dart`, `favorites_screen.dart`, `settings_screen.dart` | `UserStore`, Favoriler, Ayarlar | 3 |
| `theme.dart` | tema jetonları ve stiller | 3 |
| `fare_service.dart`, `events_service.dart`, `weather_service.dart`, `feedback_service.dart` | ağ katmanı + ilgili store'lar | 4 |
| `screens/events_screen.dart`, `event_detail_screen.dart` | Etkinlikler | 4 |
| `screens/map_screen.dart`, `location_service.dart`, `place_search_screen.dart`, `widgets/category_sheet.dart` | Harita ekranı, `MapModel`, konum servisi, yer arama | 5 |
| `journey_planner.dart`, `walk_barriers.dart`, `routing_service.dart`, `trip_planner_screen.dart` | planlayıcı, Yol tarifi ekranı | 6 |
| `home_screen.dart`, `onboarding_screen.dart`, `splash_screen.dart` | Anasayfa, onboarding, açılış | 7 |
| `review_prompt.dart` | değerlendirme isteği | 8 |
| `analytics.dart`, `ads_service.dart` | analitik, reklam | 9 |
| `basemap.dart`, `config.dart` içindeki döşeme ayarı | gerekmiyor (MapKit) | — |

## Riskler

- **Veri kopyasının eskimesi:** Flutter tarafında veri değişip burada eşitleme
  unutulursa iki uygulama farklı veri gösterir. `DATA_SOURCE` hangi commit'te
  olduğumuzu söyler; her yayın öncesi `Scripts/sync-data.sh` çalıştırılır.
  Kalıcı çözüm, veriyi iki uygulamanın da tükettiği ortak bir yere taşımak
  (bu planın kapsamı dışında).
- **Apple Haritalar altlığı:** dış ilçelerde sokak/POI ayrıntısı OpenStreetMap'ten
  zayıf olabilir. Faz 5'in ilk işi bu kontrol. Harita kodu tek bir view sınırının
  arkasında tutulacak; gerekirse MapLibre'ye geçiş o sınırda yapılır.
- **SwiftUI `Map` ve çok sayıda işaret:** görünür POI sayısı sınırlanacak;
  yetmezse `MKMapView` + `UIViewRepresentable` kaçış kapısı.
- **Düzeltme kurallarının iki kopyası:** `hat_overrides`/`board_overrides` hem
  Dart'ta hem Swift'te olacak. Altın dosya testleri sapmayı yakalar.
- **Dart ↔ Swift davranış farkları:** Türkçe büyük/küçük harf, regex kelime
  sınırı, dizgi karşılaştırması (UTF-16 birimi / Unicode eşdeğerliği), sıralama
  kararlılığı, mesafe yuvarlama. Bu yüzden portlar altın dosyalarla doğrulanıyor.
