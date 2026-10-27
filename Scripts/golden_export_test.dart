// İzmir Dolmuş iOS — altın dosya dışa aktarımı.
//
// Bu dosya iOS deposuna aittir ve tek başına çalıştırılmaz:
// Scripts/export-golden.sh onu Flutter deposunun test/ klasörüne geçici olarak
// kopyalar, `flutter test` ile çalıştırır ve siler.
//
// Flutter uygulamasının GERÇEK kodunu (Repository, HatOverrides, trNorm…)
// çağırıp sonuçları GOLDEN_OUT klasörüne JSON olarak yazar. Swift tarafındaki
// GoldenTests aynı girdilerle aynı çıktıyı üretmek zorundadır.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:izmir_dolmus/hat_overrides.dart';
import 'package:izmir_dolmus/journey_planner.dart';
import 'package:izmir_dolmus/models.dart';
import 'package:izmir_dolmus/repository.dart';
import 'package:izmir_dolmus/routing_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FNV-1a 64: her dizginin UTF-8 baytları, ardından ayırıcı olarak 0x0A.
/// Binlerce dizgiyi dosyaya dökmeden karşılaştırmak için.
String fnv(Iterable<String> items) {
  var h = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  for (final s in items) {
    for (final b in utf8.encode(s)) {
      h = (h ^ b) * prime;
    }
    h = (h ^ 0x0a) * prime;
  }
  final hi = (h >> 32) & 0xffffffff, lo = h & 0xffffffff;
  return hi.toRadixString(16).padLeft(8, '0') +
      lo.toRadixString(16).padLeft(8, '0');
}

// Hat araması sorguları (Repository.searchHats).
const hatQueries = [
  'buca', 'Buca Bornova', 'bornova buca', 'karşıyaka', 'KARŞIYAKA', 'karsiyaka',
  'evka 5', 'evka', 'otogar', 'üçkuyular', 'f altay', 'f. altay', 'F.ALTAY',
  'hastane', 'hst', 'şehir hastanesi', 'cd', 'mah', 'univ', 'ist', 'istasyon',
  'torbalı', 'kemalpaşa torbalı', 'kemalpaşa', 'çeşme', 'ÇEŞ', 'm41', 'mevlana',
  'gediz', 'ödemiş', 'tire', '1. güzergah', 'güzergah', 'ışıkkent', 'isikkent',
  'IŞIKKENT', 'bornova metro', 'x', 'zzz', 'a', 'konak', 'alsancak',
  'narlıdere', 'Güzelbahçe', 'urla', 'sanayi', 'toki', 'TOKİ', 'aosb',
  '  buca   otogar  ', 'katip çelebi', 'kâtip', 'ring', 'eski yol', 'otoyol',
  'bergama', 'dikili', 'foça', 'menemen', 'aliağa', 'seferihisar', 'selçuk',
  'kiraz', 'beydağ', 'bayındır', 'karaburun', 'mimkent', 'manavkuyu', 'egekent',
  'şirinyer', 'hal', 'gıda çarşısı', 'meydan', 'meydani', 'cami', 'köy',
];

// Yer araması sorguları (Repository.placeMatches).
const placeQueries = [
  'konak', 'alsancak iskele', 'alsancak', 'cami', 'camii', 'benzinlik',
  'ege üniversitesi', 'bornova metro', 'şehir hastanesi', 'forum', 'optimum',
  'otogar', 'atatürk ilkokulu', 'ilkokulu', 'eczane', 'pazar', 'pazar yeri',
  'mah', 'atatürk cd', 'sk', '1. sanayi', 'üçyol', 'ucyol', 'halkapınar',
  'havalimanı', 'adnan menderes', 'kordon', 'saat kulesi', 'agora',
  'kemeraltı', 'fuar', 'kültürpark', 'stadyum', 'devlet hastanesi', 'lisesi',
  'anadolu lisesi', 'belediye', 'çarşı', 'sahil', 'site', 'köprü', 'tire',
  'bergama', 'çeşme', 'alaçatı', 'foça', 'ab', 'abc', 'xyz123', 'İZMİR',
  'izmir', 'ızmır', 'kâtip çelebi', 'katip celebi', 'migros', 'bim', 'a101',
  'şok', 'hilton', 'starbucks', 'izban', 'metro', 'tramvay', 'iskele',
  'karşıyaka iskele', 'üniversite', 'univ', 'hst', 'ist', 'meydan', 'park',
  'müze', 'kütüphane', 'postane', 'ptt', 'okul', 'evka 3', 'evka', 'mavişehir',
  'bostanlı', 'göztepe', 'güzelyalı', 'balçova', 'narlıdere', 'buca koop',
  'şirinyer', 'hatay', 'basmane', 'çankaya', 'gıda çarşısı', 'sanayi sitesi',
  '  konak   meydan  ', 'KONAK', 'Konak · Konak', 'cad', 'bulvar', 'blv',
];

// Uygulamada placeMatches'in çağrıldığı limitler.
const placeLimits = [1, 6, 12, 25];

// Haritanın odağı. Uygulamada Repository.focusCenter hiç boş kalmaz: harita
// ekranı açılışta İzmir merkezini atar, sonra kamera hareket ettikçe günceller.
// Odaksız çağrıda eşit sıradaki sonuçların sırası Dart'ın (kararsız)
// sıralamasına kalır; o yüzden karşılaştırma hep bir odakla yapılır.
const centers = {
  'merkez': LatLng(38.4237, 27.1428),
  'bornova': LatLng(38.4622, 27.2160),
  'karsiyaka': LatLng(38.4590, 27.1150),
  'tire': LatLng(38.0890, 27.7350),
};

const trNormSamples = [
  'KARŞIYAKA', 'Gaziemir', '  Üçkuyular  ', 'İZMİR', 'IŞIKKENT', 'ığdır',
  'Kâtip Çelebi', 'KÂTİP ÇELEBİ', 'Î î Û û Â â', 'a\tb\nc', 'non breaking',
  'ΑΘΗΝΑ ΣΟΦΟΣ', 'İ', 'I', 'ı', 'i', 'i̇', 'İstanbul', 'é',
  'ß', 'STRASSE ẞ', 'ＡＢＣ １２３', '', '   ', 'F.Altay', 'Çeşme–Alaçatı',
  '🐟 Balıkçı', 'Ǆ ǅ ǆ', 'ŞİRİNYER / BUCA', 'Ege Üniv. Hst.',
];

const queryTokenSamples = [
  'atatürk cd', 'Cad. no 5', 'mah', 'İst', 'univ hst', '  ', 'şehir hastanesi',
  'ilkokulu ortaokulu', 'meydani bulvar', 'cami sok', 'BLV cadd mh',
];

// Harita: "Önemli Noktalar" kategorileri (map_screen.dart'taki _categories).
const categoryTypes = [
  ['hastane'], ['universite'], ['avm'], ['metro', 'izban', 'tramvay'],
  ['otogar'], ['iskele'], ['okul'], ['park'], ['muze', 'turistik'],
  ['stadyum', 'spor'], ['pazar'], ['eczane'],
];

// Yol tarifi: Flutter kodundaki yorumlarda geçen zor durumlar (isimle bulunur).
const tripPairs = [
  ['Hasanağa Bahçesi', "Looffy's"],
  ['FP Arena', 'İzotaş'],
  ['Bornova Metro', 'Fatma Saygın'],
  ['Kamil Tunca', 'Buca Otogar'],
  ['Konak', 'Adnan Menderes Havalimanı'],
  ['Adnan Menderes Havalimanı', 'Konak'],
  ['Şirinyer', 'Işıkkent'],
  ['Evka 3', 'Ege Üniversitesi'],
  ['Karşıyaka İskele', 'Bornova Metro'],
  ['Gaziemir', 'Buca'],
];

// Harita: görünür alan sorgusu için zoom seviyeleri. Kutu boyu zoom'la küçülür.
const poiZooms = [12.0, 13.5, 15.0, 16.5, 17.0];

String kindLetter(String kind) => switch (kind) {
      'durak' => 'd',
      'mahalle' => 'm',
      'cadde' => 'c',
      'okul' => 'o',
      'eczane' => 'e',
      'hastane' => 'h',
      'pazar' => 'p',
      _ => '?',
    };

void main() {
  test('altın dosyaları dışa aktar', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final outDir = Platform.environment['GOLDEN_OUT'];
    if (outDir == null) fail('GOLDEN_OUT tanımlı değil');

    final repo = Repository.instance;
    await repo.load();

    // Her kayıt kendi satırında: git farkları okunur kalsın.
    void writeLines(String name, Iterable<Object?> entries) {
      final body = entries.map(jsonEncode).join(',\n');
      File('$outDir/$name').writeAsStringSync('[\n$body\n]\n');
    }

    List<double> ll(LatLng p) => [p.latitude, p.longitude];

    writeLines('hats.json', [
      for (final h in repo.hats)
        {
          'id': h.id,
          'name': h.name,
          'apiCode': h.apiCode,
          'ilce': h.ilce,
          'feeLabel': h.feeLabel,
          'segments': [for (final s in h.segments) s.id],
          'keyStops': h.keyStopNames.length,
          'keyStopsHash': fnv(h.keyStopNames),
          'info': HatOverrides.infoFor(h.id),
        }
    ]);

    writeLines('geoms.json', [
      for (final h in repo.hats)
        {
          'hat': h.id,
          'geoms': [
            for (final g in repo.geomsFor(h.id))
              {
                'ad': g.ad,
                'yon': g.yon,
                'n': g.pts.length,
                'boardable': g.board.where((b) => b).length,
                'boardHash': fnv([g.board.map((b) => b ? '1' : '0').join()]),
                'first': ll(g.pts.first),
                'last': ll(g.pts.last),
              }
          ],
        }
    ]);

    writeLines('districts.json', [
      for (final (ilce, hats) in repo.hatsByDistrict())
        {
          'name': ilce,
          'hats': [for (final h in hats) h.id],
        }
    ]);

    writeLines('hat_search.json', [
      for (final q in hatQueries)
        {
          'q': q,
          'ids': [for (final h in repo.searchHats(q)) h.id],
        }
    ]);

    final placeRuns = <(String, int, String)>[
      for (var i = 0; i < placeQueries.length; i++)
        (placeQueries[i], placeLimits[i % placeLimits.length], 'merkez'),
      for (final center in ['bornova', 'karsiyaka', 'tire'])
        for (var i = 0; i < placeQueries.length; i += 4)
          (placeQueries[i], 12, center),
    ];
    writeLines('place_search.json', [
      for (final (q, limit, center) in placeRuns)
        {
          'q': q,
          'limit': limit,
          'near': ll(centers[center]!),
          'results': [
            for (final p in repo.placeMatches(q, limit: limit, near: centers[center]))
              [p.label, p.latLng.latitude, p.latLng.longitude]
          ],
        }
    ]);

    // Satırlar hat sırasıyla: iOS tarafı satırları hatların içinde tutar.
    final segments = [for (final h in repo.hats) ...h.segments];
    final text = {
      'trNorm': [
        for (final s in trNormSamples) [s, trNorm(s)]
      ],
      'queryTokens': [
        for (final s in queryTokenSamples) [s, queryTokens(s)]
      ],
      'counts': {
        'hats': repo.hats.length,
        'routes': repo.routes.length,
        'duraklar': repo.duraklar.length,
        'landmarks': repo.landmarks.length,
      },
      // Bütün veri üzerinde trNorm: tek tek yazmak yerine özet.
      'normHashes': {
        'hatNames': fnv(repo.hats.map((h) => trNorm(h.name))),
        'routeNames': fnv(segments.map((r) => trNorm(r.name))),
        'stops': fnv(segments.expand((r) => r.stops).map(trNorm)),
        'duraklar': fnv(repo.duraklar.map((d) => trNorm(d.label))),
        'landmarks': fnv(repo.landmarks.map((l) => trNorm(l.name))),
      },
      // Yer türleri: yer başına bir harf (d/m/c/o/e/h/p), dosyadaki sırayla.
      'kinds': {
        'duraklar':
            repo.duraklar.map((d) => kindLetter(repo.placeKind(d.label))).join(),
        'landmarks':
            repo.landmarks.map((l) => kindLetter(repo.placeKind(l.name))).join(),
      },
    };
    File('$outDir/text.json').writeAsStringSync(
        '${const JsonEncoder.withIndent(' ').convert(text)}\n');

    // --- Harita (Faz 5) ---------------------------------------------------
    // Yakın hatlar: merkezler, her 120. önemli nokta ve İzmir üzerinde 6x6 ızgara.
    final probes = <LatLng>[
      ...centers.values,
      for (var i = 0; i < repo.landmarks.length; i += 120) repo.landmarks[i].latLng,
      for (var a = 0; a < 6; a++)
        for (var b = 0; b < 6; b++)
          LatLng(38.20 + a * 0.10, 26.90 + b * 0.10),
    ];
    writeLines('nearby_hats.json', [
      for (var i = 0; i < probes.length; i++) ...[
        {
          'p': ll(probes[i]),
          'max': 800,
          'limit': 25,
          'results': [
            for (final n in repo.nearbyHats(probes[i])) [n.hat.id, n.meters]
          ],
        },
        if (i % 5 == 0)
          {
            'p': ll(probes[i]),
            'max': 2000,
            'limit': 1,
            'results': [
              for (final n in repo.nearbyHats(probes[i], maxMeters: 2000, limit: 1))
                [n.hat.id, n.meters]
            ],
          },
      ],
    ]);

    // Görünür alandaki noktalar: her merkezde zoom'a göre küçülen kutular.
    writeLines('pois_in_view.json', [
      for (final c in centers.values)
        for (final z in poiZooms)
          () {
            final half = 0.03 / (1 << (z - 12).floor()) * (z % 1 == 0 ? 1 : 0.7);
            final south = c.latitude - half, north = c.latitude + half;
            final west = c.longitude - half * 1.2, east = c.longitude + half * 1.2;
            return {
              'box': [south, north, west, east],
              'zoom': z,
              'results': [
                for (final poi in repo.poisInView(south, north, west, east, z))
                  [poi.label, poi.type, poi.latLng.latitude, poi.latLng.longitude]
              ],
            };
          }(),
    ]);

    // Kategoriler: her tür grubu, iki merkeze göre (uzaklık sırası).
    writeLines('places_in_category.json', [
      for (final types in categoryTypes)
        for (final center in ['merkez', 'tire'])
          {
            'types': types,
            'near': ll(centers[center]!),
            'results': [
              for (final p in repo.placesInCategory(types, near: centers[center]))
                [p.label, p.latLng.latitude, p.latLng.longitude,
                  const Distance().as(LengthUnit.Meter, centers[center]!, p.latLng)]
            ],
          },
    ]);

    // --- Yol tarifi (Faz 6) ------------------------------------------------
    // Uygulamadaki akışın aynısı: planla, yürüme bacaklarının uzunluğunu çöz
    // (kuş uçuşu × walkDetourFactor), yeniden sırala, baskınlık güvencesi.
    LatLng? placeOf(String q) {
      final m = repo.placeMatches(q, limit: 1, near: centers['merkez']);
      return m.isEmpty ? null : m.first.latLng;
    }
    final tripRuns = <(String, LatLng, LatLng)>[
      for (final pair in tripPairs)
        if (placeOf(pair[0]) != null && placeOf(pair[1]) != null)
          ('${pair[0]} → ${pair[1]}', placeOf(pair[0])!, placeOf(pair[1])!),
      for (var i = 0; i < 30; i++)
        ('lm$i', repo.landmarks[(i * 193) % repo.landmarks.length].latLng,
            repo.landmarks[(i * 389 + 77) % repo.landmarks.length].latLng),
    ];
    final tripEntries = <Object?>[];
    for (final (name, a, b) in tripRuns) {
      final js = repo.planJourneys(a, b);
      for (final j in js) {
        for (final leg in j.walks) {
          final r = await RoutingService.footRoute(leg.from, leg.to);
          if (r != null) leg.pathMeters = r.$2;
        }
      }
      JourneyPlanner.rank(js);
      JourneyPlanner.applyDominance(js);
      tripEntries.add({
        'name': name,
        'from': ll(a),
        'to': ll(b),
        'journeys': [
          for (final j in js)
            {
              'key': j.rides.map((r) => r.hatId).join('>'),
              'estMinutes': j.estMinutes,
              'transfers': j.transfers,
              'walkMeters': j.walkMeters,
              'rideMeters': j.rideMeters,
              'feeMin': j.feeMin,
              'feeMax': j.feeMax,
              'score': j.sortScore,
              'legs': [
                for (final leg in j.legs)
                  if (leg is WalkLeg)
                    ['walk', ...ll(leg.from), ...ll(leg.to), leg.straightMeters, leg.toLabel]
                  else if (leg is RideLeg)
                    ['ride', leg.hatId, leg.geomIndex, ...ll(leg.board), ...ll(leg.alight),
                      leg.meters, leg.ridePts.length]
              ],
            }
        ],
      });
    }
    writeLines('trips.json', tripEntries);
  });
}
