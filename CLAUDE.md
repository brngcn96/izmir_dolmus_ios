# İzmir Dolmuş iOS

İzmir Dolmuş'un native iOS (SwiftUI) sürümü. Android sürümü ayrı bir repo'da
durur (Flutter; yerelde `../izmir_dolmus`, GitHub'da `marfuj/izmir_dolmus`); bu
repo ona bağımlı olmadan derlenir ve o repo'ya iOS dosyası eklenmez.

Plan, kararlar ve faz ilerlemesi `PLAN.md`'dedir. iOS işine başlamadan önce oku;
ilerlemeyi orada işaretle (faz kutuları ve en üstteki durum satırı).

## Çalışma düzeni (öğrenme odaklı)

Kullanıcı orta seviye bir iOS geliştirici: Swift 5 ve programatik UIKit'te iyi,
SwiftUI'da yeni. Bu projeyi SwiftUI'ı, Swift 6 eşzamanlılığını ve modern ağ
katmanını öğrenerek yazmak istiyor; ne öğrenme aşamasını atlamak ne de öğrenirken
çok vakit kaybetmek istiyor. Türkçe konuş.

- Bir fazı uçtan uca kendin yazma. İskeleti, veri/algoritma portlarını ve
  tekrarlayan kodu sen yaz; `PLAN.md`'de "Sen" diye listelenen 4-6 kilit parçayı
  kullanıcıya bırak.
- Kullanıcının yazacağı yeri `// ✍️ SEN (S2.1): …` işaretli, derlenen bir yer
  tutucuyla bırak; uygulama her an çalışır durumda kalsın.
- Kodu sohbette ver: dosya, işaret, kısa "neden böyle". Vermeden önce birebir
  aynısını geçici olarak yerine koyup derle ve simülatörde çalıştır, sonra geri al.
- Kullanıcı "yazdım" deyince dosyasını oku, derle ve test et, geri bildirim ver.
- Faz sonunda konu anlatımı: kavramlar UIKit/GCD karşılıklarıyla, sık yapılan
  hatalar, 3-5 kontrol sorusu. Commit yalnızca kullanıcının onayıyla.

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

# Aynı testler Xcode şemasından (simülatörde); Xcode'da ⌘U
xcodebuild test -project IzmirDolmus.xcodeproj -scheme IzmirDolmus \
  -destination 'platform=iOS Simulator,name=iPhone 17'

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

## API doğrulama

Xcode 27, iOS 27 SDK ve Swift 6.4 kullanılıyor; minimum hedef iOS 26.0. Bu
sürümler model bilgisinden yeni olabilir: bir API'nin varlığını ve hangi iOS
sürümünde geldiğini hafızadan değil SDK'daki `.swiftinterface` dosyalarından
doğrula (`$(xcrun --sdk iphoneos --show-sdk-path)` altında
`System/Library/Frameworks/{SwiftUI,SwiftUICore,_MapKit_SwiftUI}.framework/Modules/`
ve `usr/lib/swift/CoreLocation.swiftmodule/`). `.swiftinterface` yalnızca imzaları
verir; bir API'nin belge açıklaması (davranışı, örnek kullanımı) aynı klasördeki
`.swiftdoc` dosyasında düz metin olarak durur ve `strings` ile okunabilir.
