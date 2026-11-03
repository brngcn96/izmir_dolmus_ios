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
| Yaş sınırı | 4+ (bütün sorulara "Yok / Hayır") |
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

iPhone 6,9 inç (1320×2868): `screenshots-6.9/` içindeki yedi dosyayı numara sırasıyla
yükle. İlk üçü sayfada öne çıkıyor: Anasayfa, haritada tarif, kilit ekranında yolculuk.

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
Form. No ads, analytics or tracking in this version.
```

## Uygulama gizliliği (App Privacy) cevapları

Bu sürüm için (reklam gelince, Faz 9'da, yeniden doldurulacak):

- **Veri topluyor musun?** Evet.
- **Kullanıcı içeriği › Diğer kullanıcı içeriği** (geri bildirim notu ve cevapları):
  amaç Uygulama işlevi; kimlikle ilişkilendirilmez; izleme için kullanılmaz.
- **Konum › Yaklaşık konum** (hava durumu için ~1 km'ye yuvarlanmış koordinat):
  amaç Uygulama işlevi; kimlikle ilişkilendirilmez; izleme için kullanılmaz.
- Diğer bütün türler: toplanmıyor. Kesin konum cihazdan çıkmıyor.

Uygulamanın gizlilik manifestindeki (`IzmirDolmus/PrivacyInfo.xcprivacy`) toplanan
veri bölümü bu cevaplarla aynı.
