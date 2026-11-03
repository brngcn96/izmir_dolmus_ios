# İzmir Dolmuş iOS

İzmir Dolmuş'un native iOS (SwiftUI) sürümü. Android sürümü ayrı bir repo'da
durur (Flutter; yerelde `../izmir_dolmus`, GitHub'da `marfuj/izmir_dolmus`); bu
repo ona bağımlı olmadan derlenir ve o repo'ya iOS dosyası eklenmez.

Plan, kararlar ve faz ilerlemesi `PLAN.md`'dedir. iOS işine başlamadan önce oku;
ilerlemeyi orada işaretle (faz kutuları ve en üstteki durum satırı).

## Çalışma düzeni (2026-10-27'den itibaren: hızlı)

Kullanıcı orta seviye bir iOS geliştirici: Swift 5 ve programatik UIKit'te iyi,
SwiftUI'da yeni. Faz 0–4'ü öğrenerek, parçaları kendisi yazarak geçti; zamanı
daraldığı için Faz 5'ten itibaren düzen değişti. Türkçe konuş.

- Fazları uçtan uca sen yaz; kullanıcıya parça ya da yer tutucu bırakma.
- Her fazı derle, testleri koş, simülatörde doğrula; dokunma gerektiren akışları
  açıkça belirt.
- Faz sonunda kısa bir özet ver: ne yapıldı, nasıl doğrulandı, önemli bulgular.
  `PLAN.md`'yi güncelle ve açıklamalı, İngilizce bir commit at (kullanıcının
  2026-10-27 tarihli kalıcı onayı; mesajın sonuna `Co-Authored-By` satırı).
- Konu anlatımları en sona kaldı: bütün fazlar bitince, `PLAN.md`'deki faz
  konuları projedeki koddan alıntılarla, UIKit/GCD karşılıklarıyla toplu anlatılır.
- **İstisna, Faz W (widget'lar) ve Faz Y (Yolculuk modu), 2026-10-29:** yeniden
  interaktif. Xcode yapılandırmalarını (hedef, yetenekler, Info) kullanıcı yapar.
  Kilit kod parçalarının kodunu sen verip açıklarsın, kullanıcı yazar; sen derler,
  test eder, doğrularsın. Altyapıyı (çekirdek modeller ve testleri, derin bağlantılar,
  doğrulama) sen yazarsın. Konu anlatımı parçalarla birlikte o anda yapılır.
  Yolculuk modunda acele yok, hazırlık titiz olmalı.
- **Güncelleme, 2026-11-02:** kullanıcı hızlanmak istedi: denemeleri ve Faz Y'nin
  kalanını (Y3–Y4) sen yaparsın; konu anlatımı faz sonunda, koddan alıntılarla verilir.
- **Faz 10 (yayın), 2026-11-03:** kullanıcı önce interaktif yapmak istedi (SF.1–SF.3'ü
  kendisi yaptı), sonra "bu fazı sen yap" dedi. Kalanını sen yaparsın. Yalnızca hesaba
  bağlı adımlar (Apple Developer üyeliği, App Store Connect'te girilen bilgiler, yükleme
  onayı) kullanıcıdadır; onlar için tam tıklama yollarıyla kısa bir liste ver.

## Yapı

- `IzmirDolmus/` — uygulama hedefi. Varsayılan izolasyon `MainActor`,
  Approachable Concurrency açık. Klasör Xcode ile eşitlenir: diske eklenen dosya
  projeye kendiliğinden girer, `project.pbxproj` düzenlemek gerekmez.
- `DolmusCore/` — yerel Swift paketi: model, veri, arama, geometri, planlayıcı,
  ağ. Varsayılan izolasyon yok; tipler `Sendable` değer tipleri. UIKit/SwiftUI
  içermez. Projeye klasör başvurusuyla bağlıdır (kök paket); böylece testleri
  paylaşılan `IzmirDolmus` şemasının Test eyleminden de koşar.
- `DolmusCore/Sources/DolmusCore/Resources/` — veri dosyaları. Elle düzenlenmez;
  `Scripts/sync-data.sh` Flutter repo'sundaki `assets/data/` klasöründen kopyalar
  ve kaynağı `DATA_SOURCE`'a yazar.
- `DolmusCore/Tests/DolmusCoreTests/Golden/` — Flutter uygulamasının gerçek
  kodundan üretilmiş beklenen çıktılar (altın dosyalar); `GoldenTests` portları
  bunlarla karşılaştırır. Elle düzenlenmez; `Scripts/export-golden.sh` yazar ve
  kaynağı `Golden/SOURCE`'a kaydeder.

## Komutlar

```sh
# Paket testleri (Mac'te, simülatörsüz)
cd DolmusCore && swift test
cd DolmusCore && swift test --filter DataLoaderTests   # tek süit

# Şemanın bütün testleri (paket + UI testleri, simülatörde); Xcode'da ⌘U
xcodebuild test -project IzmirDolmus.xcodeproj -scheme IzmirDolmus \
  -destination 'platform=iOS Simulator,name=iPhone 17'
# Yalnızca biri: -only-testing:DolmusCoreTests ya da -only-testing:IzmirDolmusUITests

# Uygulamayı simülatör için derle
xcodebuild -project IzmirDolmus.xcodeproj -scheme IzmirDolmus \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Veriyi Flutter repo'sundan eşitle
Scripts/sync-data.sh            # varsayılan kaynak: ../izmir_dolmus

# Altın dosyaları Flutter kodundan yeniden üret (veri ya da Flutter'daki
# veri/arama kodu değişince; önce sync-data.sh, sonra swift test)
Scripts/export-golden.sh        # varsayılan kaynak: ../izmir_dolmus
```

Arayüze bakmak için: `xcrun simctl boot`, `install`, `launch`, ardından
`xcrun simctl io <udid> screenshot`. İş bitince uygulamayı kaldır ve simülatörü kapat.

## UI testleri

`IzmirDolmusUITests` uygulamayı `-uiTesting` ile açar (yalnızca Debug, bkz.
`AppEnvironment`): ağ istekleri hazır cevaplarla döner (İBB, GitHub, Open-Meteo,
Google Form'a gidilmez), ayarlar her açılışta silinen ayrı bir alanda, önbellekler
geçici klasörde. Simülatördeki asıl veri değişmez; yeniden açılışı deneyen test
`-uiTestingKeepData` ile test alanını bırakır. Başlangıç değerleri argüman
alanından verilir (`-onboarding_done YES`); argüman alanı uygulamanın yazdığının
önüne geçer, uygulamanın değiştireceği bir değeri böyle sabitleme.
Derin bağlantıyı `openLink(_:)` (`XCUIDevice.shared.system.open`) ile aç:
`app.open(_:)` bir "launch"tır, uygulamayı adresle yeniden başlatabilir ve o zaman
test argümanları düşer (uygulama tanıtımla, gerçek ayarlarla açılır).
`AccessibilityAuditTests` Apple'ın erişilebilirlik denetimini ana ekranlarda varsayılan
ve en büyük yazı boyutunda koşar; sistem bileşenlerinden gelen bilinen sorunlar
testteki listede gerekçesiyle durur.

## API doğrulama

Xcode 27, iOS 27 SDK ve Swift 6.4 kullanılıyor; minimum hedef iOS 26.0. Bu
sürümler model bilgisinden yeni olabilir: bir API'nin varlığını ve hangi iOS
sürümünde geldiğini hafızadan değil SDK'daki `.swiftinterface` dosyalarından
doğrula (`$(xcrun --sdk iphoneos --show-sdk-path)` altında
`System/Library/Frameworks/{SwiftUI,SwiftUICore,_MapKit_SwiftUI}.framework/Modules/`
ve `usr/lib/swift/CoreLocation.swiftmodule/`). `.swiftinterface` yalnızca imzaları
verir; bir API'nin belge açıklaması (davranışı, örnek kullanımı) aynı klasördeki
`.swiftdoc` dosyasında düz metin olarak durur ve `strings` ile okunabilir.
