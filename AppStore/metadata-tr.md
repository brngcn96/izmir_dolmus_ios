# App Store Connect bilgileri (sürüm 1.0)

App Store Connect'te girilecek metinler. Alan sınırları içinde (ad ve alt başlık 30,
tanıtım metni 170 karakter, anahtar kelimeler 100 bayt). Hesaba bağlı adımlar için
`PLAN.md`'deki Faz 10 listesine bak.

## Uygulama bilgileri (App Information)

| Alan | Değer |
|---|---|
| Ad (Name) | İzmir Dolmuş |
| Alt başlık (Subtitle) | Dolmuş hatları ve yol tarifi |
| Birincil dil | Türkçe |
| Paket kimliği (Bundle ID) | com.izmirdolmus.app |
| SKU | izmirdolmus-ios |
| Birincil kategori | Navigasyon (Navigation) |
| İkincil kategori | Seyahat (Travel) |
| Yaş sınırı | 4+ (bütün sorulara "Yok / Hayır"; reklamlar uygulamada genel izleyiciye uygun içerikle sınırlı) |
| Fiyat | Ücretsiz |
| Gizlilik politikası adresi | https://izmirdolmus.com/gizlilik (güncel sayfa yayına alınmış olmalı) |
| Destek adresi (Support URL) | https://izmirdolmus.com |
| Pazarlama adresi (Marketing URL) | https://izmirdolmus.com |
| Telif (Copyright) | 2026 (geliştirici hesabındaki ad) |
| Üçüncü taraf içerik | Evet: İBB'nin açık verisi (hatlar, ücretler) ve kamuya açık etkinlik listeleri; kullanım hakkı var |

Ad App Store'da başka bir uygulamada kullanılıyorsa: "İzmir Dolmuş: Hat ve Ücret".

## Sürüm sayfası (1.0)

**Tanıtım metni (Promotional Text)**

İzmir'deki dolmuş hatları, güncel ücretler ve kapıdan kapıya yol tarifi tek uygulamada. Yolculuk modu inişine yaklaşınca seni uyarır.

**Açıklama (Description)**

İzmir Dolmuş, İzmir'in bütün dolmuş hatlarını, güzergahlarını ve güncel ücretlerini tek yerde toplar; nereden nereye gideceğini söyle, hangi dolmuşa bineceğini göstersin.

HATLAR VE ÜCRETLER
• İlçe ilçe bütün dolmuş hatları; ada ya da durağa göre anında arama
• Her hattın resmi güzergahı, geçtiği kilit noktalar ve ücret bölgeleri
• Ücretler İzmir Büyükşehir Belediyesi'nin servisinden güncellenir

HARİTA VE YOL TARİFİ
• Haritada bir yere uzun bas, oradan geçen hatları gör
• Nereden → Nereye: aktarmalı ya da aktarmasız seçenekler, süre ve ücret tahminiyle
• Adım adım tarif; yürüme bacağını Apple Haritalar'da aç
• Yakınındaki hatlar ve önemli noktalar (hastane, okul, iskele, metro…)

YOLCULUK MODU
• Tarifi başlat, kilit ekranında ve Dynamic Island'da o anki adımı gör
• İnişine yaklaşınca uyarı; güzergahtan çıkarsan haber verir
• Yolculuk bitince ya da sen bitirince konum kullanımı durur

WIDGET'LAR
• "Eve / İşe" widget'ı: saate göre doğru yönde en iyi tarif
• Favori hatların ana ekranda; Denetim Merkezi'nden tek dokunuşla yol tarifi

DAHA FAZLASI
• İzmir'deki konserler, tiyatrolar ve etkinlikler; etkinliğe nasıl gideceğin
• Favoriler, Ev ve İş adresleri, son aramalar
• Hesap yok, kayıt yok; hat verisi telefonda, internet olmadan da hat arayıp tarif alabilirsin

Süreler ve ücretler yaklaşıktır; sefer saati verisi yoktur. İzmir Dolmuş resmi bir İBB uygulaması değildir.

**Anahtar kelimeler (Keywords)**

dolmuş,minibüs,izmir,ulaşım,hat,güzergah,ücret,yol tarifi,bornova,buca,karşıyaka,otobüs

**Bu sürümdeki yenilikler (What's New)**

İlk sürüm.

## Ekran görüntüleri

iPhone 6,9 inç (1320×2868): `screenshots-6.9/` içindeki sekiz dosyayı numara sırasıyla
yükle. İlk üçü sayfada öne çıkıyor: Anasayfa, haritada tarif, kilit ekranında yolculuk.
Görüntülerde reklam yok (Debug derlemesi `-noAds` argümanıyla çekildi).

## İnceleme notu (App Review Information › Notes)

İnceleme ekibi İngilizce okuyor; not İngilizce:

```
İzmir Dolmuş shows minibus (dolmuş) lines, fares and directions for İzmir, Turkey.
No account or login is needed.

Background location: used only in "Journey mode". The user starts it from a route
by tapping "Yolculuğu başlat" (Start journey). A Live Activity shows the current
step; location is used in the background only while that journey runs, with
When In Use authorization and CLBackgroundActivitySession (no Always
authorization). It stops when the user arrives, taps "Bitir" (End), or after at
most 4 hours.

To try without being in İzmir: tap the search field on the home screen, enter
"Bornova Metro" as the origin and "Şirinyer" as the destination, tap "Rota bul"
(Find route), pick the recommended option and tap "Yolculuğu başlat". Nearby lines
on the home screen need a location in İzmir (e.g. 38.4581, 27.2125).

Weather: Apple WeatherKit. Optional line feedback is sent to the developer's Google
Form.

Ads: Google AdMob. A banner sits above the tab bar (not on the Map tab); an app open
ad is shown at most once a day when the app comes to the foreground, and an
interstitial at most once a day when going back from a pushed screen. There are no
full-screen ads in the first session after installing. The App Tracking Transparency
prompt is shown once, after the location permission has been answered; ads also work
without tracking permission. Where consent is required (EEA, UK), Google's consent
form is shown, and Settings > Hakkında > "Reklam gizlilik seçenekleri" lets the user
change it. No analytics.
```

## Uygulama gizliliği (App Privacy) cevapları

Sürüm 1.0, reklamlı. Uygulamanın kendi topladıkları (geri bildirim, hava durumu için
yaklaşık konum) ile Google Mobile Ads 13.12.0 ve UMP 3.1.0'ın gizlilik manifestlerinde
beyan ettikleri birleştirildi; SDK güncellenince manifestlere yeniden bakılmalı.
Amaçların App Store Connect'teki adları: Third-Party Advertising, Developer's
Advertising or Marketing, Analytics, App Functionality.

- **Veri topluyor musun?** Evet.
- **Konum › Yaklaşık konum**: Uygulama işlevi (hava durumu, ~1 km), Üçüncü taraf
  reklamcılığı, Geliştiricinin reklamcılığı, Analiz. Kimlikle ilişkilendirilir: **Evet**
  (AdMob). İzleme: Hayır.
- **Kullanıcı içeriği › Diğer kullanıcı içeriği** (geri bildirim notu ve cevapları):
  Uygulama işlevi. İlişkilendirilmez. İzleme: Hayır.
- **Tanımlayıcılar › Cihaz kimliği** (reklam kimliği, izin verilirse): Üçüncü taraf
  reklamcılığı, Geliştiricinin reklamcılığı, Analiz. İlişkilendirilir: **Evet**.
  İzleme: **Evet**.
- **Kullanım verileri › Ürün etkileşimi**: Üçüncü taraf reklamcılığı, Geliştiricinin
  reklamcılığı, Analiz, Uygulama işlevi (rıza formu). İlişkilendirilir: **Evet**.
  İzleme: Hayır.
- **Kullanım verileri › Reklam verileri**: Üçüncü taraf reklamcılığı, Geliştiricinin
  reklamcılığı, Analiz. İlişkilendirilir: **Evet**. İzleme: Hayır.
- **Tanılama › Çökme verileri**: Analiz. İlişkilendirilmez. İzleme: Hayır.
- **Tanılama › Performans verileri**: Üçüncü taraf reklamcılığı, Geliştiricinin
  reklamcılığı, Analiz, Uygulama işlevi (rıza formu). İlişkilendirilmez. İzleme: Hayır.
- **Tanılama › Diğer tanılama verileri**: Üçüncü taraf reklamcılığı, Geliştiricinin
  reklamcılığı, Analiz. İlişkilendirilmez. İzleme: Hayır.
- Diğer bütün türler: toplanmıyor. Kesin konum cihazdan çıkmıyor.

Cihaz kimliği izleme için kullanıldığından ürün sayfasında "Sizi İzlemek İçin
Kullanılan Veriler" bölümü çıkar; uygulama bunun için izleme izni (ATT) ister.
Uygulamanın kendi gizlilik manifesti (`IzmirDolmus/PrivacyInfo.xcprivacy`) yalnızca
uygulamanın kendi topladıklarını beyan eder; SDK'larınki kendi paketlerinde.
