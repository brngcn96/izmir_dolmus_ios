# İzmir Dolmuş iOS — Plan

Plan tarihi: 2026-10-08 · Durum (2026-10-29): Faz 0–7 ve Faz W bitti · sırada Faz Y (Yolculuk modu, interaktif), sonra Faz 8 · çalışma düzeni (aşağıda)

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
| Çalışma düzeni | Faz 0–4: dengeli, faz başına 4-6 kilit parçayı sen yazdın. **2026-10-27'den itibaren:** kodu Claude yazar, faz sonunda kısa özet ve açıklamalı commit; konu anlatımları en sonda toplu | Kullanıcının zamanı daraldı. |
| iOS'a özgü özellikler | **Faz W** (widget'lar) ve **Faz Y** (Yolculuk modu: Live Activity ile canlı takip), Faz 8'den önce; ikisi de interaktif | Flutter'da yok; kullanıcı bu konuları öğrenerek yapmak istiyor (2026-10-29). |

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

Faz 0–4 öğrenme odaklı yürüdü: iskeleti ben yazdım, faz başına 4-6 kilit parçayı
sen yazdın, faz sonunda konu anlatımı yapıldı. **2026-10-27'den itibaren (Faz 5 ve
sonrası):**

1. **Kod:** fazı uçtan uca ben yazarım (port, ekranlar, testler); yer tutucu yok.
2. **Doğrulama:** derleme, testler ve ayrı bir simülatörde ekran görüntüleri;
   dokunma gerektiren akışlar ayrıca belirtilir.
3. **Faz sonu:** kısa özet (ne yapıldı, nasıl doğrulandı, önemli bulgular), bu
   dosyanın güncellenmesi ve açıklamalı İngilizce commit (kalıcı onayınla).
4. **Konu anlatımı:** en sonda, bütün fazların "Konu anlatımı" maddeleri koddan
   alıntılarla toplu anlatılır.

**İstisna, Faz W ve Faz Y (2026-10-29):** yeniden interaktif. Xcode yapılandırmalarını
(hedef, yetenekler, Info ayarları) sen yaparsın. Kilit kod parçalarının kodunu ben
verip açıklarım, sen yazarsın. Ben derler, test eder, simülatörde doğrularım.
Konu anlatımı en sona kalmaz, parçalarla birlikte o anda yapılır. Altyapı
parçalarını (çekirdek modeller ve testleri, derin bağlantılar, doğrulama) ben yazarım.

Süreler senin tarafındaki kaba tahmindir; bu düzende fazlar senin açından kısalır.

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
  6'ya geçiş S0.1'in işi. Uygulamanın kendi test hedefi yok: domain testleri
  pakette, UI testi hedefi Faz 8'de Xcode'dan eklenecek.
- Paket testleri Xcode'dan da koşar (2026-10-09): `DolmusCore` projeye klasör
  başvurusuyla bağlı (kök paket) ve paylaşılan `IzmirDolmus` şemasının Test
  eylemi `DolmusCoreTests`'i içeriyor; ⌘U seçili simülatörde çalıştırır. Paket
  `XCLocalSwiftPackageReference` ile bağlıyken şema test hedefini göremiyordu.
- **Konu anlatımı:** UIKit'ten SwiftUI'a zihin haritası — AppDelegate/SceneDelegate
  → `App`/`Scene`; `UIView` (kalıcı nesne) → `View` (geçici tarif); `body`'nin
  yeniden hesaplanması ve kimlik; şablondaki eşzamanlılık ayarlarının anlamı.
- **Bitti sayılır:** temiz derleme, simülatörde açılış, `swift test` yeşil.
- **Sonuç (2026-10-08):** üçü de sağlandı. Team seçilmedi (`DEVELOPMENT_TEAM`
  boş): simülatör için gerekmiyor, gerçek cihaza kurulumdan önce seçilecek.

### [x] Faz 1 — Veri katmanı: Swift 6 ile domain (~3-4 saat)
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
- **Sonuç (2026-10-09):** S1.1–S1.5 yazıldı ve doğrulandı: 27 test yeşil (altın
  dosyalar dahil), uygulama simülatörde 410 hattı listeliyor, JSON çözmenin ana
  thread dışında yapıldığı testle kanıtlı (`@concurrent` silinince test
  kırılıyor). Yer tutucu hatası (`Unwritten.swift`), `SetupCheck.swift` ve
  `CheckRow` silindi.
- **Konu anlatımı:** Swift 6 eşzamanlılık modeli (izolasyon alanları, MainActor
  varsayılanı, `nonisolated`, `@concurrent`, `Sendable`, veri yarışı güvenliği;
  GCD karşılıkları), değer tipleriyle modelleme, `Codable` derinlemesine, Swift Testing.
- **Bitti sayılır:** altın dosyalar dahil testler yeşil; ana thread'de JSON çözme yok.

### [x] Faz 2 — Gezinme iskeleti: Liquid Glass tab bar + NavigationStack + Router (~4-5 saat)
- **Çıktı:** cam tab bar'lı sekmeli uygulama; Hatlar (ilçe grupları + anlık arama)
  → Hat detayı (temel); sekme başına bağımsız gezinme yığını; alt sayfa örneği.
- **Karar noktası:** sekme düzeni — (A) Android'deki 5 sekme, (B) 4 sekme + ayrık
  arama düğmesi olarak Hatlar. S2.3'teki `hatsIsSearchTab` sabiti ikisi arasında
  geçiş yapar; simülatörde deneyip seçeceksin. Karardan sonra sabit ve
  kullanılmayan dal silinir.
- **Karar (2026-10-14): B.** Hatlar, tab bar'ın yanında ayrı search button;
  seçilince arama açılır (`.tabViewSearchActivation(.searchTabSelection)`).
  Tab'ın başlığı "Hatlar" (görünmez, VoiceOver okur), simgesi büyüteç.
- **Ben (yapıldı):** `AppTab`, kök (`RootView`: yükleme kapısı), `DataStore.data`,
  hat detayının parçaları (`HatSummarySections`, `FareRowsSection`, `FareSheet`),
  `HatDestinationView` (kimlikten hat), `HomeView` (Router ile programatik geçiş
  örneği), `ComingSoonView`; `DolmusData.empty`.
- **Sen:** S2.1 `enum Route: Hashable` + `NavigationStack(path:)` +
  `navigationDestination(for:)` (`Navigation/Route.swift`; yol önce yerel
  `@State`) · S2.2 `@Observable` `Router` (seçili sekme + sekme başına yol) ve
  `@Environment` ile dağıtımı (`Router.swift`, `Route.swift`'in yeni hali,
  `IzmirDolmusApp.swift`) · S2.3 `TabView` + `Tab` API + arama rolü +
  `tabViewSearchActivation` + `tabBarMinimizeBehavior` (`MainTabView.swift`) · S2.4
  `.searchable` + açılır-kapanır ilçe bölümleri (`Hatlar/HatListView.swift`) · S2.5
  `.sheet(item:)` + `presentationDetents` (`Hatlar/HatDetailView.swift`).
- **Doğrulama (2026-10-09):** altı durum (yer tutucular, S2.1 … S2.5) sırayla
  derlendi; ekranlar ayrı bir simülatörde (iOS 27.0) görüntülendi: iki sekme
  düzeni, ilçe bölümleri, arama sonuçları ve boş sonuç, detay, alt sayfa, Router
  ile sekmeler arası geçiş. Dokunma gerektiren akışlar (satıra dokunup itme,
  bölüm açma, yazarak arama, aynı sekmeye yeniden dokunup köke dönme) komut
  satırından sürülemediği için başlangıç durumları ve Router üzerinden denendi;
  elle denemesi sende.
- **Sekme çubuğu notları (iOS 27.0 simülatörü):**
  - `Tab(role: .search)` tek başına ayrık düğme olmaz; sıradan bir sekme gibi
    sona yerleşir. Ayrık düğme ve alttaki arama alanı ancak `TabView`'a
    `.tabViewSearchActivation(.searchTabSelection)` eklenince gelir: sekme
    seçilince arama açılır, kapatılınca önceki sekmeye dönülür.
  - `.searchable` `TabView`'a konursa arama alanı bütün sekmelerin gezinme
    çubuğuna sızar; arama sekmesinin içinde (`HatListView`) durmalı.
  - iOS 27'de `TabRole.prominent` ayrık düğmeyi özel simgeyle verir; en düşük
    hedef 26.0 olduğu için kullanılmadı.
  - Belge açıklamaları SDK'daki `.swiftdoc` dosyalarından okunabilir
    (`strings` ile); `.swiftinterface` yalnızca imzaları verir.
- **Gözlemler (2026-10-15, `Self._printChanges()` ile):**
  - Tab içerikleri ilk seçildiklerinde oluşturuluyor; açılışta yalnızca
    Anasayfa'nın `RouteStack`'i var.
  - `Router.paths` tek property olduğu için bir tab'ın path'i değişince o ana
    kadar oluşturulmuş bütün `RouteStack`'ler yeniden hesaplanıyor. Tab başına
    ayrı bir `@Observable` nesne (`TabNavigation`, `let` ile tutulan) bunu yalnızca
    path'i değişen tab'a indiriyor; deponun kopyasında denendi. Beş tab için
    gerek görülmedi; ölçek büyürse geçilecek.
  - Anasayfa'daki örnek düğme detail'i Hatlar tab'ının stack'ine açıyor; path
    tab değişince korunuyor.
- **Konu anlatımı:** NavigationStack derinlemesine (değer tabanlı gezinme, yol
  durumu, hedeflerin nerede tanımlanacağı, köke dönme, sheet mi push mu, sık
  hatalar), TabView ve Liquid Glass davranışı, UINavigationController/Coordinator karşılıkları.
- **Bitti sayılır:** liste → detay → geri, sekme değiştirme ve köke dönme tutarlı;
  Router'dan programatik geçiş çalışır.

### [x] Faz 3 — Durum yönetimi ve tasarım sistemi (~4-5 saat)
- **Çıktı:** Favoriler, Ayarlar (Ev/İş, son aramalar), tam Hat detayı (ücret
  bölgeleri, kilit nokta çipleri, oy/not); tema jetonları, Figtree, koyu mod, Dynamic Type.
- **Sen:** S3.1 `UserStore` (favoriler, Ev/İş, son aramalar; UserDefaults
  kalıcılığı; `Stores/UserStore.swift`) · S3.2 `@Bindable`/`Binding` ile Ev/İş
  düzenleme (`Sekmeler/SettingsView.swift`) · S3.3 `Layout` protokolüyle
  `FlowLayout` (`Design/FlowLayout.swift`) · S3.4 `ViewModifier` + `ButtonStyle`
  ile kart ve buton stilleri (`Design/Styles.swift`) · S3.5 `glassEffect` +
  `GlassEffectContainer` ile yüzen kontrol (`Hatlar/HatActionBar.swift`).
- **Ben (yapıldı):** tema token'ları ve Figtree yardımcıları (`Design/Theme.swift`,
  ücret renkleri Assets'te açık/koyu), navigation bar başlıkları Figtree,
  `FavoritesView`, Ayarlar parçaları (`SavedPlaceRow`, `PlacePickerView`,
  `RecentPlacesSection`, `AboutSection`), `HatRow`'da favori yıldızı ve ücret
  rengi, detail'de chip'ler; erişilebilirlik boyutlarında satırların alt alta
  dizilmesi; `PlacePoint: Encodable` (+2 test); `UserDefaults` JSON yardımcısı.
- **Kapsam değişikliği:** hat detail'indeki oy ve not Faz 4'e taşındı. Flutter'da
  bunlar bir geri bildirim formu (`feedback_service` ile gönderiliyor); yerel oy
  sayısı tek başına 0/1'den ibaret. Gönderimle birlikte yazılacak.
- **Doğrulama (2026-10-15):** altı durum (yer tutucular, S3.1 … S3.5) derlendi.
  Çözümler yerindeyken ayrı simülatörde: favoriler ekleniyor ve uygulama yeniden
  açılınca kalıyor; Hatlar listesinde favori yıldızı görünüyor; Ev adresi
  kaydediliyor; chip'ler satıra sarıyor; cam kontroller detail'de; açık, koyu ve
  en büyük erişilebilirlik boyutunda görüntülendi. Erişilebilirlik boyutunda
  satırlar ilk denemede kelime ortasından bölünüyordu, alt alta dizilerek
  düzeltildi. Dokunarak yapılan akışlar (yıldıza basmak, yer seçmek, uzun basıp
  favoriden çıkarmak) elle denenecek.
- **Sonuç (2026-10-15):** S3.1–S3.5 yazıldı; verilen kodla birebir aynı, derleniyor,
  29 test yeşil. Kontrolde benim tarafımda bir hata çıktı: `Theme.applyNavigationBarFonts()`
  `App.init` içinde çağrılınca uygulamanın vurgu rengi (AccentColor) sistem
  mavisine düşüyordu (seçili tab, varsayılan button'lar). Çağrı `RootView`'un
  `onAppear`'ına taşındı; marka rengi açık ve koyu modda geri geldi, başlıklar
  Figtree kaldı. Not: başlık puntosu açılıştaki yazı boyutuna göre bir kez
  ayarlanıyor; uygulama açıkken yazı boyutu değişirse ancak yeniden açılışta
  güncellenir.
- **Konu anlatımı:** SwiftUI veri akışı (`@State`, `@Binding`, `@Observable`,
  `@Bindable`, `@Environment`), view kimliği ve ömrü, özel `Layout`, stiller,
  Liquid Glass'ın nerede kullanılıp nerede kullanılmayacağı.
- **Bitti sayılır:** favori değişikliği tüm ekranlara anında yansır ve yeniden
  açılışta kalır; koyu modda ve en büyük yazı boyutunda ekranlar bozulmaz.
- **Not:** bir tab'dan açılan hat detail'i o tab'ın kendi stack'ine push edilir
  (Favoriler → Favoriler'in stack'i); her `RouteStack` `Route.hat`'i zaten tanıyor.

### [x] Faz 4 — Modern ağ katmanı (~4-5 saat)
- **Çıktı:** İBB'den ücret tazeleme (yaklaşık 400 hat kodu, en çok 6 eşzamanlı
  istek, ilerleme, iptal); Etkinlikler (liste, filtreler, detay, 6 saatlik
  önbellek); hava durumu; geri bildirim gönderimi.
- **Sen:** S4.1 `APIClient.send`: `Endpoint` → `URLRequest`, transport, durum
  kodu, decode, typed throws ile `APIError`, `@concurrent`
  (`DolmusCore/.../Network/APIClient.swift`) · S4.2 `FareRefresher.refresh`:
  `withTaskGroup` ile en çok 6 eşzamanlı istek, ilerleme, iptal
  (`DolmusCore/.../Fares/FareRefresher.swift`) · S4.3 `EventsView`: `.task` +
  `.refreshable` + yükleniyor/hata/boş/liste (`Etkinlikler/EventsView.swift`) ·
  S4.4 `EventCard`: `AsyncImage` fazları + `AnyLayout` (`Etkinlikler/EventCard.swift`)
  · S4.5 `APIClientTests`: `actor FakeTransport` ile gerçek sunucuya gitmeyen
  testler (`DolmusCoreTests/APIClientTests.swift`).
- **Ben (yapıldı):**
  - `DolmusCore`: `HTTPTransport` (+ `URLSession` uyumu), `APIError`,
    `Endpoint` protocol'ü ve dört endpoint (İBB ücret, etkinlikler, Open-Meteo,
    Google Form), `FileCache` (zaman damgalı JSON), `FareRow`/`FareTable`/
    `FareRefreshResult`, `DolmusData.applyingLiveFares` + `fareCodes`
    (`DolmusRoute`: `bakedFee`, `liveFee`, hesaplanan `fee`), `EventItem` (esnek
    decode, iki tarih biçimi), `EventFeed`, `EventFilter`/`EventCategory`, Türkçe
    tarih ve fiyat etiketleri, `WeatherInfo`, `HatFeedback`. Testler:
    `NetworkModelTests`, `EventTests`, `LiveFaresTests`, `FileCacheTests`,
    `FareRefresherTests`.
  - Uygulama: `FareStore` (önbellek, 14 günde bir kendiliğinden tazeleme,
    ilerleme, iptal), `EventsStore` (6 saatlik önbellek, süren isteği paylaşma),
    `FeedbackStore` (oy ve not kalıcılığı, gönderim), `EnvironmentValues.apiClient`
    (`@Entry`), etkinlik detayı ve filtre çubuğu (cam chip'ler, mekan sheet'i),
    Ayarlar'da "Ücretler", hat detail'inde geri bildirim, Anasayfa'da hava durumu
    (`async let`) ve Etkinlikler girişi.
  - Senin dosyalarında küçük bağlantı değişiklikleri: `Route` (`.events`,
    `.event(id:)`), `DataStore.applyLiveFares`, `SettingsView` (`FaresSection`),
    `HatDetailView` (`HatFeedbackSection`), `IzmirDolmusApp` (üç yeni store).
- **Doğrulama (2026-10-15):** altı durum (yer tutucular, S4.1 … S4.5) derlendi.
  Yer tutucularla 53 test var, `FareRefresherTests`'in 4'ü kırmızı (S4.1 + S4.2
  ile yeşile döner); hepsi yerindeyken 58 test yeşil. Çözümler yerindeyken ayrı
  simülatörde gerçek ağla:
  - 396 hat kodu yaklaşık 10 sn'de geldi, hiçbiri başarısız olmadı. 2235 ücret
    satırının 1852'si İBB'deki adlarla eşleşti, 12'si gömülü veriden farklı
    (ör. KRB02/KRB03 "Karaburun-Mordoğan" 45 → 130, MND07 yok → 70, TİR05 245 → 240).
  - Etkinlikler (106 görünür), detay, filtreler, mekan sheet'i, boş sonuç, hava
    durumu; açık, koyu ve en büyük yazı boyutu.
  - Ağ yokluğu, iptal ve canlı ücretin detail'e yansıması sahte transport'la
    denendi (gerçek sunucuya yük bindirmeden). Geri bildirim gerçek forma hiç
    gönderilmedi; gönderim yolu sahte transport'la denendi.
  - Dokunma gerektirenler (aşağı çekip yenileme, filtre menüleri, mekan seçimi,
    iptal düğmesi, oy düğmeleri, gönderim) elle denenecek.
- **Bulgular:**
  - `withTaskGroup`'un body'si, onu çağıran fonksiyon `nonisolated(nonsending)`
    olsa da çağıranın aktöründe kalmıyor (bu SDK'da deneyle görüldü). Body closure'ı
    ancak `isolated` parametreyi yakalarsa onun aktöründe çalışıyor; parametreyi
    `withTaskGroup(isolation:)`'a geçirmek tek başına yetmiyor. Bu yüzden
    `FareRefresher`'ın ilerleme callback'i tipinde `@MainActor`.
  - İçi boş bir `List` gruplu zemini çizmiyor (beyaz kalıyor); Etkinlikler'de
    `scrollContentBackground(.hidden)` + `Color.canvas`.
  - List satırındaki devre dışı button siyah çiziliyor; gönder düğmesinin rengi
    duruma göre veriliyor.
  - Kaynaktaki Ticketmaster saatleri UTC (`17:30Z` = 20:30). Flutter uygulaması
    çevirmediği (`toLocal` yok) için büyük olasılıkla 3 saat erken (17:30)
    gösteriyor; iOS İzmir saatiyle gösteriyor. Android'de düzeltilmeli.
  - Flutter, bütün ücret istekleri başarısız olsa da tazeleme tarihini ilerletiyor
    (14 gün yeniden denemiyor). iOS'ta hiç cevap gelmezse tarih ilerlemez.
  - Canlı ücretlerin bindirilmesi debug'da 12 ms. İlk hali 38 ms'ydi; satırlar
    artık kod başına bir kez normalize ediliyor, ilçe kopyaları kimlikle bulunuyor.
  - Geri bildirim metnine "Platform: iOS …" satırı eklendi (iki uygulama aynı
    forma yazıyor).
  - Etkinlik detayındaki "Yol tarifi" Faz 6'da; "Haritada göster" şimdilik Harita
    sekmesini açıyor (mekan Faz 5'te işaretlenecek).
  - `@concurrent` deneyle: `APIClient.send` ana aktörden çağrıldığında transport
    ana thread dışında çalışıyor; `@concurrent` silinince ana thread'de. Gerçek
    `URLSession` iptal edilen isteği `URLError.cancelled` (-999) ile bitiriyor.
- **Sonuç (2026-10-15):** S4.1–S4.5 yazıldı; verilen kodla birebir aynı, 58 test
  yeşil. Kullanıcı Etkinlikler'de bir titreme buldu: listeyi aşağı kaydırıp tek
  hamlede hızla yukarı fırlatınca, tepeye varırken navigation bar büyük başlıkla
  küçük başlık arasında gidip geliyor ve bozuk bir yerleşimde (başlık geri
  düğmesinin üstünde, arama alanı yok) kalabiliyordu.
  - Ölçüm: geçici bir XCUITest projesi uygulamayı paket kimliğiyle açıp
    fırlattı; ekran kaydının karelerinden içeriğin dikey kayması çıkarıldı.
    Tepeye varışta kayma yönü 20 kez değişiyordu.
  - Kök neden: `.safeAreaBar(edge: .top)` ile kaydırırken yüksekliği değişen bir
    navigation bar (büyük başlığın küçülmesi ya da arama alanının gizlenmesi)
    birlikte. Varyantlar: bar'sız 0, `safeAreaInset` 0 (ama kenar efekti yok,
    içerik chip'lerin arasından görünüyor), büyük başlık + arama hep açık 21,
    inline başlık + gizlenen arama 27, aramasız büyük başlık 25, inline başlık +
    arama hep açık 0.
  - Düzeltme (`EventsView`): `.navigationBarTitleDisplayMode(.inline)` ve
    `.searchable(…, placement: .navigationBarDrawer(displayMode: .always), …)`;
    üç ayrı fırlatmada yön değişimi 0, kenar efekti duruyor.
- **Konu anlatımı:** yapılandırılmış eşzamanlılık (`async let`, `TaskGroup`, iptal,
  `.task` ömrü), ağ katmanı tasarımı (uç nokta, hata tipleri, zaman aşımı,
  önbellek), completion handler/OperationQueue karşılıkları.
- **Bitti sayılır:** uçak modunda önbellekle çalışır; tazeleme iptal edilebilir;
  ağ testleri gerçek sunucuya gitmeden yeşil.

### [x] Faz 5 — Harita I: MapKit (~5-6 saat)
- **Altlık kararı (2026-10-16/27):** Bergama, Tire, Çeşme, Ödemiş, Karaburun ve
  Mordoğan'da Apple Haritalar ile OSM yan yana karşılaştırıldı. Apple'da sokak ağı
  ve adları altı noktada da var, otogarlar işaretli; bina şekilleri ve bazı ana
  yolların vurgusu OSM'den zayıf. Dolmuş bilgisi (çizgiler, duraklar, noktalar)
  kendi verimizden çizildiği için **MapKit'le devam** edildi.
- **Yapılanlar (hepsi Claude):**
  - `DolmusCore/Map`: Vincenty uzaklığı (`latlong2` ile aynı, tam metreye
    yuvarlanmış), çizgiye düzlem uzaklığı, `HatGeom.nearestBoardable` (otoyol
    parçaları atlanır), `nearbyHats` (800 m, 25), `nearestGeomIndex`, POI dizini
    (~400 m ızgara, tür başına en düşük zoom ve öncelik) ve `poisInView`,
    `placesInCategory`, çizgiye dokunma için `hats(onLinesOf:near:toleranceMeters:)`.
  - Altın dosyalar: `nearby_hats.json` (107 sorgu), `pois_in_view.json` (20),
    `places_in_category.json` (24); `MapGoldenTests` Dart'ın kararsız sıralamasını
    hesaba katarak (eşit anahtarlı gruplar küme olarak) karşılaştırır.
  - Uygulama (`Harita/`): `MapModel` (seçilen nokta, yakın hatlar, renkli
    önizleme çizgileri, tek hat ve güzergah çipleri, bir adım geri, kamera ve
    noktalar), `MapScreen` (`Map(position:bounds:)`, `MapReader` + uzun basma için
    `UIGestureRecognizerRepresentable`, dokunmayla çizgi tanıma, kamera durunca
    noktaların yenilenmesi), `LocationProvider` (`CLServiceSession` +
    `CLLocationUpdate.liveUpdates()`, 12 sn sınır), yakın hatlar sheet'i
    (arkadaki harita kullanılabilir), "Önemli Noktalar" kategorileri, haritada arama.
  - `Router.showOnMap`: hat detail'i ve etkinlik detayındaki "Haritada göster"
    haritayı ilgili hat ya da yerle açar; harita boşaltılınca gelinen sekmeye dönülür.
- **Doğrulama:** 64 test yeşil; bilerek bozulan üç kural (durak önceliği,
  binilebilir parçanın iki ucu, kategori tekrar anahtarı) yakalandı. Gerçek
  hareketlerle (geçici XCUITest projesi: uzun basma, dokunma, kıstırma) ayrı
  simülatörde: boş harita, uzun basma → yakın hatlar, önizleme çizgileri, tek hat
  ve güzergah çipleri, geri adımları, konumum (simüle konum), kategoriler,
  arama, yakınlaşınca noktalar, hat detail'inden "Haritada göster" ve geri dönüş;
  açık ve koyu mod. Çizgiye dokunmanın hesabı birim testli; dokunmanın kendisi
  elle denenecek.
- **Bulgular:**
  - Güzergah çiplerinde `ForEach(geoms.indices)` + `geoms[index]` "geri"de
    çöktürüyordu: dizi boşalırken bant bir kez daha çiziliyor. Çipler elemanın
    kendisi üzerinden kuruldu.
  - Koyu haritada beyaz etiket dış hattı okunmuyordu; dış hat renk şemasına
    göre (koyuda siyah).
  - Flutter haritada aynı anda en çok 30 nokta çiziyor (`poisInView`'in 160'lık
    varsayılanı değil); aynısı yapıldı.
  - Yol tarifi düğmeleri (nokta panelinde, etkinlik detayında) Faz 6'da.
- **Konu anlatımı (en sonda):** MapKit for SwiftUI (içerik oluşturucu, `MapCameraPosition`,
  `MapReader`, performans), CoreLocation'ın async API'leri, jestler;
  `UIViewRepresentable` ile `MKMapView`'a ne zaman inilir.
- **Bitti sayılır:** Flutter'daki harita senaryoları çalışır; kaydırma akıcı.

### [x] Faz 6 — Yol tarifi (~4-5 saat)
- **Yapılanlar (hepsi Claude):**
  - `DolmusCore/Trip`: `journey_planner.dart` ve `walk_barriers.dart` portu.
    `JourneyPlanner` aktarmasız (halka hatlar için bütün geçişler) ve tek
    aktarmalı rotaları bulur, yürüme engelini (havalimanı) geçenleri eler, sıralar,
    aynı hat kombinasyonundan tek seçenek bırakır, "önerilen" için baskınlık
    güvencesi uygular. `planTrip` uygulamadaki akışı izler: yürüme bacaklarını
    çöz (kuş uçuşu × 1,2), yeniden sırala. Kurulum ve planlama `@concurrent`
    yardımcılarla ana aktör dışında. Ücretler planlama anında güncel veriden okunur.
  - Altın dosya `trips.json`: Flutter'ın gerçek koduyla 38 uç çifti (17'sinde rota,
    toplam 74 seçenek). Hat sırası, süre, aktarma, yürüme, ücret, puan ve her
    bacağın biniş/iniş noktaları karşılaştırılır.
  - Uygulama: "Nereden → Nereye" sayfası (`TripPlannerView`: yazarken
    `.task(id:)` ile 200 ms beklemeli öneriler, takas, "Konumumu kullan", Ev/İş,
    son aramalar); haritada yol tarifi modu (yürüme kesik gri, dolmuşlar renkli,
    biniş ve uç işaretleri), seçenekler listesi ("Önerilen"), alt bant, adım adım
    tarif, yürüme bacağını Apple Haritalar'da yaya yol tarifiyle açma
    (`MKMapItem(location:address:)`). Girişler: Anasayfa, seçilen noktanın
    panelindeki "Yol tarifi" (varış dolu gelir), etkinlik detayı, haritadaki
    "Nereden → Nereye" çipi (düzenleme).
- **Doğrulama:** 66 test yeşil; bilerek bozulan üç kural (yürüme katsayısı,
  aktarma yürüme sınırı, yürüme engeli süzgeci) yakalandı. Gerçek hareketlerle
  (geçici XCUITest): Anasayfa → Bornova Metro → Şirinyer, seçenekler, ikinci
  seçenek, adım adım; haritada nokta → Yol tarifi → Konumumu kullan → rotalar;
  Konak → Havalimanı (rota yok, engel notu, başlangıç çevresindeki hatlar).
  Debug'da planlayıcının kurulumu ~64 ms (846 çizgi), bir planlama ~230 ms; ikisi
  de ana aktör dışında.
- **Bulgular:**
  - Bazı hatların iki varyantı aynı yoldan geçiyor (ör. M19#manavkuyu'nun gündüz
    ve akşam RİNG'leri): seçenekler her ölçüde eşit ve Dart'ın kararsız sıralaması
    hangisini öne koyacağını rastgele seçiyor. Altın test bu durumda varyant
    numarasını karşılaştırmıyor.
  - Nokta seçilince yakın hatlar listesi kendiliğinden açılınca alttaki "Yol
    tarifi" düğmesini örtüyordu; Flutter'daki gibi liste düğmeyle açılıyor.
  - List satırındaki `Label` rozeti bozuyordu (simge ayrı sütuna konuyor);
    rozet `HStack` ile kuruldu.
- **Faz 5–6 test turu (2026-10-28):** geçici XCUITest ile 18 senaryo gerçek
  hareketlerle koşturuldu. Senaryolar: nokta, önizleme, çizgiye dokunma (dokunulan
  piksel ekran görüntüsünde çizgi renginden bulunur), karttan hat, güzergah çipleri,
  POI'ye dokunma, konumum, izin yok uyarısı, kategoriler, arama, hat ve etkinlik
  detayından "Haritada göster" ile geri, koyu mod, yol tarifinin bütün girişleri,
  düzenleme, Apple Haritalar'a geçiş, havalimanı, planlayıcı doğrulaması.
  Bulunup düzeltilenler:
  - Haritada düzenlenen yol tarifi dönülecek sekmeyi siliyordu; "Geri" Anasayfa
    yerine haritada kalıyordu. `Router.showOnMap` artık haritanın içinden gelen
    istekte saklı sekmeyi korur.
  - Yalnızca nokta seçiliyken (ör. etkinlikten "Haritada göster") "Geri" noktayı
    kaldırıp haritada kalıyordu ve geri düğmesi de kayboluyordu. Harita boşalınca
    gelinen sekmeye dönülüyor. Flutter'da bu çıkışı Android'in sistem geri tuşu yapıyor.
  - POI adları ve simgeleri üst üste biniyordu. Noktalar önem sırasıyla ekrana
    yerleştiriliyor: çarpışan simge o zoom'da çizilmez, çarpışan ad yazılmaz.
    Seçilen noktanın ve yol tarifi uçlarının iğne ve ad alanı önceden ayrılır;
    önceden mahalle etiketine çarpan iğnenin adını MapKit gizliyordu.
  - Koyu modda POI adları (koyu tür rengi) ve yakın hatlar listesindeki uzaklık
    okunmuyordu. Uzaklıktaki `.secondary` button içinde tint'ten türüyordu,
    `Color.secondary` kullanılıyor. Adlar koyu modda beyazla açılıyor (`Color.mix`).
  - Apple Haritalar'ın kendi mahalle adları bizimkilerle yer yer tekrarlanıyor.
    Flutter'daki OpenFreeMap altlığında da aynısı var; eşitlik için bırakıldı.
- **Konu anlatımı (en sonda):** CPU işi için aktör mü `Sendable` değer tipi mi, `Task` iptali
  ve debounce, ViewModel'in gerçekten gerektiği yer, `@FocusState`.
- **Bitti sayılır:** aynı uçlar için iOS ve Android aynı rotaları aynı sırada
  verir (testle); planlama sırasında arayüz donmaz.

### [x] Faz 7 — Anasayfa, onboarding, açılış animasyonu (~4-5 saat)
- **Yapılanlar (hepsi Claude):**
  - `DolmusCore/Places`: `nearestPlace(to:)` (Flutter'daki
    `LocationService.currentWithNearest`, 34.638 yer üzerinde Vincenty) ve
    `IzmirDistrict` (etiketten ilçe adı; 30 ilçe, `trNorm` ile). 4 yeni test.
  - Anasayfa (`HomeView`, `HomeParts`, `HomeModel`):
    - Başlık ve konumun ilçesiyle hava durumu.
    - "Konum veya adres ara" girişi (yol tarifini açar).
    - Ev/İş/Önemli Noktalar çipleri. Ayarlı değilse adres sorar; basılı
      tutunca değiştir/kaldır.
    - Etkinlik kartı.
    - Yakındaki hatlar: gezinmeyen mini harita, 5 renkli hat ve özet etiketi.
      Satıra ya da haritaya dokununca konum Harita'da açılır.
    - Son 3 arama: dokununca haritada, okla yol tarifi.
    - Konum alınamazsa açıklama ve yeniden dene; izin reddedildiyse "Ayarlar'ı aç".
    - En yakın yer araması `@concurrent` ile ana aktörün dışında (debug'da ~12 ms).
  - Açılış (`SplashView`, `KeyframeAnimator`):
    - Dolmuş soldan easeOutCubic ile kayar; yazı animasyonun %35'inden sonra
      belirip yukarı kayar. Hareket azaltılmışsa dolmuş kaymaz.
    - Veri en baştan arka planda yüklenir. İlk açılışta tanıtım hemen gelir;
      sonraki açılışlarda açılış ekranı veri hazır olunca kapanır, uzarsa
      "Yükleniyor…" yazar.
  - Tanıtım (`OnboardingView`):
    - Sayfalı `TabView`: Atla/İleri/Başla düğmeleri ve sayfa noktaları.
    - Karşılama sayfasında dolmuş `PhaseAnimator` ile hafifçe sallanır.
    - Son sayfada konum izni bağlam içinde istenir.
    - Görülme bayrağı `@AppStorage("onboarding_done")`.
  - Zoom geçişi: `RouteStack` bir `@Namespace`'i environment ile paylaşır.
    Anasayfa'daki etkinlik kartı → Etkinlikler ve etkinlik kartı → detay
    `matchedTransitionSource` + `.navigationTransition(.zoom)` kullanır.
    Belgede kaynağı bulunamayan zoom'un ne yaptığı yazmadığı için zoom
    yalnızca kaynağı kesin bu iki geçişte.
  - Uygulama ikonu Icon Composer biçiminde (`AppIcon.icon`):
    - Android'in düz ikonu görüntü işlenerek katmanlara ayrıldı: marka
      mavisinden otomatik gradyan zemin, beyaz rota+iğne ve dolmuş. Katmanlar
      birleşince asıl ikonla aynı.
    - Eski `AppIcon.appiconset` kaldırıldı.
- **Doğrulama:** 70 test yeşil. Gerçek hareketlerle (geçici XCUITest) denenenler:
  - İlk açılış: tanıtımın üç sayfası, konum izni, "Başla".
  - Anasayfa: konum, mini harita, satırdan Harita'ya ve geri.
  - Ev'i ayarlayıp yol tarifi, basılı tutup kaldırma.
  - Önemli Noktalar → kategori → Harita → geri.
  - Etkinlik kartı ve detayda zoom geçişi; son aramadan yol tarifi.
  - Koyu mod ve büyük yazı boyutu.

  Açılış animasyonu karelerle, ikon ana ekranda görüldü. Faz 5–6 senaryoları
  yeniden geçti.
- **Bulgular:**
  - Kübik anahtar kare Hermite eğrisi kuruyor: başlangıç hızı 3 × yol ÷ süre,
    bitiş hızı 0 verilince eğri tam easeOutCubic oluyor, (t−1)³.
  - Devre dışı birincil düğme yarı saydamdı; klavyenin üstünde dururken
    altındaki liste içinden görünüyordu. Artık soluk ama opak.
  - Simülatörün simüle konumu `simctl privacy` işlemlerinden sonra zaman zaman
    düşüyor. Anasayfa o zaman 12 sn sonra "Konumun alınamadı." gösteriyor
    (beklenen davranış); konum yeniden verilince düzeliyor.
  - Icon Composer biçimi Xcode'un dosya şablonundaki `icon.json` (`fill`,
    `groups[].layers[].image-name`) ve `Assets/` klasörü. actool derliyor ve
    yedek PNG'leri (`AppIcon60x60@2x.png`…) de üretiyor. Cam, gölge ve koyu/tonlu
    görünüm ince ayarı Icon Composer'da açılıp yapılabilir.
- **Çıktı:** Anasayfa (hava durumu, arama girişi, Ev/İş/Önemli Noktalar çipleri,
  yakınındaki hatlar mini haritası, etkinlik girişi, son aramalar), ilk açılış
  tanıtımı (bağlam içinde konum izni), kayan dolmuş animasyonu; Icon Composer ile
  katmanlı (Liquid Glass) uygulama ikonu — şimdilik Android'deki düz ikon kullanılıyor.
- **Parçalar:** S7.1 `KeyframeAnimator`/`PhaseAnimator` ile açılış animasyonu · S7.2
  sayfalı onboarding · S7.3 anasayfa bileşimi (mini harita kartı, yatay çipler) ·
  S7.4 `matchedTransitionSource` + zoom geçişi · S7.5 `@AppStorage` bayrağı.
- **Konu anlatımı (en sonda):** animasyon sistemi (örtük/açık, geçişler, faz ve anahtar kare
  animasyonları), kaydırma API'leri, view bileşimi.
- **Bitti sayılır:** reklam/analitik dışında Android ile özellik eşitliği.
- **Erken yayın noktası:** buradan Faz 8 + Faz 10 ile reklamsız yayınlanabilir.

### [x] Faz W — Widget'lar (iOS'a özgü, interaktif, ~5-7 saat)
- **Kapsam (v1):**
  1. "Eve / İşe": küçük, orta ve kilit ekranı (dikdörtgen, satır içi, yuvarlak).
     Yön saate göre (04:00–13:59 İşe, sonrası Eve); ⇄ düğmesi uygulamayı açmadan
     çevirir. Dokununca tarif haritada açılır. Ev ya da İş yoksa "adresini ekle".
  2. "Favori hatlarım": küçük (seçilen tek hat, `AppIntentConfiguration`), orta
     (ilk 3–4 favori). Dokununca hat detayı açılır.
  3. Control Center kontrolü: "Yol tarifi" ve "Eve git".
- **Mimari kararlar:**
  - **Widget veriyi kendisi yüklemez.** Ölçüm: bütün veri belleğe +32,4 MB,
    planlayıcı +3,6 MB ekliyor; eklentinin bellek sınırı dar (Apple sayı vermiyor).
    Uygulama `WidgetSnapshot`'ı kurup App Group'a (`group.com.izmirdolmus.app`)
    yazar, widget yalnızca okur. Özet 36 KB (çoğu 410 hatlık katalog; tarifler ve
    favoriler 1,5 KB); release'de kurulması ~57 ms.
  - **Özet ne zaman yazılır:** favoriler, Ev/İş ya da ücretler değişince ve uygulama
    arka plana geçince. Ardından `WidgetCenter.shared.reloadTimelines(ofKind:)`.
  - **Dokunuş:** `widgetURL`/`Link` ile `izmirdolmus://…` → `onOpenURL` → Router.
    `widgetURL` adresi kapsayan uygulamada açar (SDK belgesi), özel şema yeterli.
    Faz 8'deki S8.4 burada yapılır.
  - **Kontrol:** `OpenURLIntent` yalnızca Universal Link açıyor (SDK belgesi).
    Kontrol bu yüzden uygulamayı kendisi açan bir App Intent ile yapılır
    (`supportedModes`); ayrıntı SW.10'da doğrulanacak.
  - **Sefer saati verisi yok:** widget'lar uygulamadaki gibi tahmini süre ve ücret gösterir.
  - **İmza:** projede Team yok. Simülatörde App Group hesapsız çalışır; gerçek
    cihaz için Apple Developer hesabı gerekir (Faz 10).
- **Parçalar** (S = sen, B = ben):
  - SW.1 (S, yapılandırma) Widget Extension hedefi: ürün adı `IzmirDolmusWidgets`;
    Live Activity, Control ve Configuration App Intent seçenekleri açık; iOS 26.0,
    Swift 6; `DolmusCore` bağlantısı.
  - SW.2 (S) App Groups yeteneği (iki hedef), `izmirdolmus` URL şeması, paylaşılan
    depo kodu (`AppGroup`).
  - SW.3 (B, yapıldı) `WidgetSnapshot` ve `CommuteDirection` (`DolmusCore/Widget`),
    4 test.
  - SW.4 (S) uygulama tarafı: özeti yazmak ve widget'ı tazelemek (`WidgetSync`).
  - SW.5 (S) `TimelineProvider`: placeholder, snapshot, timeline, yenileme politikası.
  - SW.6 (S) görünümler: aileler (`widgetFamily`), `containerBackground`,
    `widgetURL`, renk modları (`widgetRenderingMode`, `widgetAccentable`).
  - SW.7 (S) `Widget` ve `WidgetBundle` tanımları.
  - SW.8 (S) etkileşimli ⇄ düğmesi: `AppIntent` + `Button(intent:)`.
  - SW.9 (S) yapılandırılabilir favori hat widget'ı: `AppEntity`, `EntityQuery`,
    `WidgetConfigurationIntent`.
  - SW.10 (S) Control Center kontrolü: `ControlWidget`, `ControlWidgetButton`.
  - SW.11 (B) derin bağlantılar (`onOpenURL` → Router). Doğrulama: widget'ları
    simülatörde ana ekrana ve kilit ekranına ekleyip açık, koyu ve renklendirilmiş
    görünümde bakmak.
- **Yapılanlar (2026-10-29):**
  - **Kim yaptı:** SW.1'i ve iki entitlements dosyasındaki grubu sen yaptın. App
    Group penceresi Team olmadan açılmadı, Info.plist düzenleyicisinde de zorlandın.
    Kalan yapılandırmayı ve, isteğin üzerine, SW.5–SW.11'i ben yazdım; anlatımı
    parçalarla birlikte verdim.
  - **`DolmusCore/Widget`:**
    - `WidgetSnapshot`: tarifler, favoriler, hat kataloğu.
    - `CommuteDirection` ve `CommuteOverride`: ⇄ ile seçilen yön sıradaki
      otomatik değişime kadar geçerli.
    - `AppGroup`: ortak klasör ve ayarlar.
    - `DeepLink`: `izmirdolmus://` adresleri.
  - **`DolmusCore/Fares/FeeTier`:** ücret renk eşikleri tek yerde; uygulama ve
    widget'lar kendi renk kataloğuna çeviriyor.
  - **Uygulama:**
    - `WidgetSync`: girdiler (Ev, İş, favoriler, ücretler) değişince özeti yazar ve
      widget'ları tazeler.
    - `Router.open(_:)` ile `RootView`'daki `onOpenURL` ve `PendingDeepLink`: dışarıdan
      gelen adresleri ekrana çevirir.
  - **Eklenti (`IzmirDolmusWidgets`):**
    - "Eve / İşe": küçük, orta, kilit ekranı; ⇄ `ToggleCommuteDirectionIntent`.
    - "Favori hatlar": `AppIntentConfiguration`, `HatEntity`, `HatQuery` (öneriler ve
      Türkçe harf duyarsız arama).
    - Kontroller: "Yol tarifi", "Eve git".
  - **`Shared/` klasörü:** iki hedefte birden derlenir; kontrollerin intent'leri ve
    `PendingDeepLink` orada.
- **Doğrulama:** 79 paket testi yeşil. Simülatörde UI testiyle, gerçek hareketlerle:
  - widget'ları ana ekrana ekleme;
  - İş değişince tazelenme;
  - ⇄ (uygulama açılmadan);
  - "Edit Widget" ile hat seçme (öneri listesinde favoriler, arama kutusu var);
  - orta boyda satırdan hat detayı;
  - widget'tan haritada tarif;
  - Control Center'a kontrol ekleyip uygulama kapalıyken dokunma ("Yol tarifi"
    sayfası açıldı);
  - dört adresin (`hat`, `trip`, `plan?to=home`, `settings`) doğru ekranı açması.

  Hat seçicideki arama kutusunu denemedim.
- **Bulgular:**
  - **App Group penceresi:** Team yokken grupları hesaptan yükleyemiyor
    (`IDEDynamicCapabilityItemModelError error 3`). Simülatörde `.entitlements`
    dosyasına elle yazmak yetiyor. Simülatör derlemeleri yetkileri
    `__TEXT,__entitlements` bölümüne gömüyor; `codesign -d` boş görünüyor.
  - **Etkileşimli düğme:** `Button(intent:)` dokunuşundan sonra widget,
    `reloadTimelines` çağrılmadan yeni çizelgeyle çizildi.
  - **`MemberImportVisibility`:** eklenti hedefinde açık; `Button(intent:)` kullanan
    dosya `AppIntents`'i kendisi import etmeli.
  - **Yapılandırma farkı:** `StaticConfiguration`'lı widget'ın bağlam menüsünde
    "Edit Widget" yok, `AppIntentConfiguration`'lının var.
  - **Dokunma alanları:** orta boyda her `Link` ayrı bir dokunma alanı (erişilebilirlik
    ağacında ayrı düğme). Küçük boyda tek `widgetURL` kullanıldı.
  - **Kontroller:**
    - `OpenURLIntent` yalnızca Universal Link açıyor. Kontrol bu yüzden
      `supportedModes = .foreground` bir intent'le yapıldı: uygulama öne gelir,
      `perform` uygulamada çalışır.
    - Intent'in iki hedefte birden derlenmesi gerekti: iki hedefin paylaştığı,
      Xcode'la eşitlenen `Shared/` klasörü.
    - Uygulama kapalıyken açılışta istek ilk çizimden önce geliyor;
      `onChange(…, initial: true)` yakalıyor.
  - **Dış adres onayı:** `simctl openurl` ve `XCUIApplication.open` "Open in …?"
    onayı gösteriyor. Widget dokunuşu göstermiyor.
  - **iOS 26/27 API'leri:** iOS 26'da `openAppWhenRun` kullanımdan kaldırıldı,
    yerine `supportedModes`. iOS 27 SDK'da `allowedExecutionTargets` var; en düşük
    hedef 26 olduğu için kullanılmıyor.
- **Konu anlatımı (parçalarla birlikte):**
  - widget eklentisinin yaşam döngüsü: ayrı süreç, zaman çizelgesi, yenileme bütçesi;
  - uygulama ↔ widget veri akışı (App Group);
  - aileler ve renk modları;
  - App Intents: yapılandırma, etkileşim, kontrol;
  - derin bağlantılar;
  - UIKit dönemi karşılıkları (Today extension, `NCWidgetProviding`).
- **Bitti sayılır:**
  - widget'lar ana ekranda ve kilit ekranında doğru veriyle görünür;
  - ⇄ düğmesi uygulamayı açmadan yönü çevirir;
  - dokunuşlar doğru ekrana gider;
  - favori ya da Ev/İş değişince widget kendiliğinden tazelenir.

### [ ] Faz Y — Yolculuk modu (Live Activity, interaktif, acele yok, ~8-12 saat)
- **Fikir:** seçilen tarif "Yolculuğu başlat" ile canlı takip edilir. Kilit ekranında
  ve Dynamic Island'da o anki adım görünür: "Durağa yürü · 210 m" → "Bornova–Altındağ'a
  bin" → "İnişe 2,3 km" → "Sıradaki durakta in" → "Aktarma" → "Vardın". İnişe
  yaklaşınca uyarı verilir.
- **SDK'da doğrulanan sınırlar (2026-10-29):**
  - **Live Activity:**
    - Yalnızca uygulama öndeyken başlatılır (ya da `LiveActivityIntent` ile).
    - Arka planda güncellenir ve bitirilir.
    - İçerik durumu en çok 4 KB.
    - Biten etkinlik kilit ekranında en çok dört saat kalır.
    - `update(_:alertConfiguration:)` güncellemeyle birlikte uyarı verir.
    - `ActivityStyle` (`.standard`/`.transient`) iOS 18'de geldi.
  - **Arka planda konum (`CLBackgroundActivitySession`, iOS 17):**
    - "Kullanırken" izniyle arka planda konum verir; mavi durum çubuğu/hap görünür.
    - `UIBackgroundModes`'ta `location` gerekir.
    - Oturum yalnızca uygulama öndeyken başlar, arka planda sürer.
    - Uygulama arka planda yeniden açılırsa oturum hemen yeniden kurulmalıdır.
    - "Her zaman" izni gerekmez.
  - **Konum akışı:** `CLLocationUpdate.liveUpdates(.otherNavigation)` navigasyon
    kullanımına ayarlı. Bölge izleme için `CLMonitor` (iOS 17) da var.
  - **Simülatör:** `simctl location start --speed=<m/sn> <enlem,boylam>…` bir rota
    boyunca konum üretir. Bir dolmuş yolculuğu bacak bacak benzetilebilir.
- **Tasarım:**
  - **Çekirdek (`DolmusCore`), `JourneyTracker`:** tarifin bacakları ve konumdan
    şunları çıkarır:
    - o anki adım,
    - binişe ve inişe kalan yol boyu mesafe (güzergaha izdüşüm),
    - uyarı eşikleri (inişe ~400 m ve ~150 m),
    - GPS gürültüsüne karşı histerezis,
    - rotadan çıkma.

    Gerçek tarifler boyunca üretilmiş gürültülü sentetik izlerle test edilir.
  - **Uygulama, `JourneySession`:**
    - Live Activity'yi başlatır, günceller, bitirir.
    - Konum akışını yönetir; yeniden açılışta sürdürür.
    - Live Activity kapalıysa uyarı için yerel bildirim yedeği.
  - **Live Activity arayüzü** (widget eklentisinde, `ActivityConfiguration`):
    - kilit ekranı görünümü;
    - Dynamic Island: genişletilmiş bölgeler, compact leading/trailing, minimal;
    - düğmeler: "Bitir" ve "Sonraki adım" (`LiveActivityIntent`).
  - **Paylaşılan tür:** `ActivityAttributes` hem uygulamada hem eklentide
    derlenmeli (hedef üyeliği). `DolmusCore`'a konamaz: ActivityKit macOS'ta yok,
    paket ise Mac'te test ediliyor.
- **Parçalar:**
  - SY.1 (B) tasarım ve sınırlar anlatımı.
  - SY.2 (B) `JourneyTracker` ve sentetik iz testleri.
  - SY.3 (S, yapılandırma) `NSSupportsLiveActivities`, Background Modes › Location
    updates, paylaşılan dosyanın hedef üyeliği, konum izni metninin güncellenmesi.
  - SY.4 (S) `ActivityAttributes` ve `ContentState`.
  - SY.5 (S) kilit ekranı ve Dynamic Island arayüzü.
  - SY.6 (S) başlatma, güncelleme, bitirme (`JourneySession`).
  - SY.7 (S) arka planda konum ve yeniden açılışta sürdürme.
  - SY.8 (S) uyarılar (`AlertConfiguration`, yerel bildirim yedeği).
  - SY.9 (S) `LiveActivityIntent` düğmeleri.
  - SY.10 (B+S) simülatörde rota benzetimiyle uçtan uca deneme. Gerçek cihazda
    yürüyüş ve dolmuş denemesi sende.
- **Riskler:**
  - GPS doğruluğu (şehir içi, kapalı alan).
  - Dolmuşun güzergahtan sapması.
  - Pil.
  - App Review'da arka planda konumun gerekçesi: kullanıcının başlattığı, görünür
    ve yolculuk bitince kapanan bir özellik olmalı.
- **Konu anlatımı:**
  - ActivityKit: öznitelikler, içerik durumu, yaşam döngüsü, eskime;
  - Dynamic Island düzeni;
  - arka planda konum ve iOS'un uygulama yaşam döngüsü;
  - App Intents'in uygulama sürecinde çalışması;
  - yerel bildirimler;
  - UIKit/GCD karşılıkları (`allowsBackgroundLocationUpdates`, `CLLocationManager` delegeleri).
- **Bitti sayılır:**
  - simülatörde benzetilen bir yolculukta adımlar doğru sırayla ilerler;
  - inişe yaklaşınca uyarı gelir;
  - Dynamic Island ve kilit ekranı doğru görünür;
  - yolculuk bitince etkinlik ve konum oturumu kapanır.

### [ ] Faz 8 — Kalite: erişilebilirlik, performans, testler (~3-4 saat)
- **Çıktı:** VoiceOver ve Dynamic Type uyumu, gereksiz yeniden çizimlerin
  temizliği, kritik akış UI testi, değerlendirme isteği; isteğe bağlı olarak
  izmirdolmus.com hat sayfalarından uygulamaya Universal Link.
- **Parçalar:** S8.1 erişilebilirlik etiketleri · S8.2 `Self._printChanges()` ile
  yeniden çizim avı · S8.3 bir akış için XCUITest · S8.4 `onOpenURL` → Router ·
  S8.5 `requestReview` kuralları.
- **Konu anlatımı (en sonda):** SwiftUI performans modeli (bağımlılık takibi, kimlik,
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
- **Parçalar:** S9.1 `Analytics` cephesi · S9.2 banner için `UIViewRepresentable`
  sarmalayıcı · S9.3 ATT akışı · S9.4 `scenePhase` ile App Open tetikleme.
- **Konu anlatımı (en sonda):** UIKit ↔ SwiftUI köprüleme, Swift 6 altında `Sendable`
  olmayan 3. parti SDK'lar, ATT ve gizlilik kuralları.
- **Bitti sayılır:** test reklamları doğru anlarda görünür; izin reddinde
  uygulama sorunsuz çalışır.

### [ ] Faz 10 — Yayın (~3-4 saat + inceleme süresi)
- **Çıktı:** imzalama, App Store Connect kaydı, gizlilik etiketleri, ekran
  görüntüleri, TestFlight, incelemeye gönderim; web sitesine App Store bağlantısı;
  Figtree (SIL OFL) lisans bildirimi.
- **Konu anlatımı (en sonda):** imzalama ve provisioning, App Review'da sık ret nedenleri
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
