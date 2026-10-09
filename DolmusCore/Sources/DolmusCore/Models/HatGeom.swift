/// Resmi İBB güzergah geometrisi: bir hattın tek yöndeki çizgisi (UKOME
/// kararına göre çizilmiş).
public struct HatGeom: Sendable, Equatable {
    public let ad: String
    /// "GİDİŞ" / "DÖNÜŞ" / "RİNG" ya da boş.
    public let yon: String
    public let points: [Coordinate]
    /// `points` ile aynı uzunlukta: o noktada binilebilir mi. Otoyol/çevreyolu
    /// üzerindeki noktalar `false`: dolmuş orada durmaz, yaya yürüyemez. Biniş
    /// noktası ve "yakın hat" hesabı bunları atlar.
    public let boardable: [Bool]

    public init(ad: String, yon: String, points: [Coordinate], boardable: [Bool]? = nil) {
        self.ad = ad
        self.yon = yon
        self.points = points
        self.boardable = boardable ?? Array(repeating: true, count: points.count)
    }

    /// `index`'teki nokta binilebilir mi (bayrağı yoksa binilebilir sayılır).
    public func isBoardable(at index: Int) -> Bool {
        index < boardable.count ? boardable[index] : true
    }

    /// Ham İBB verisini temizleyerek kurar. Bilinen iki veri hatasını düzeltir:
    ///
    /// 1. Bazı adların başında `KOD_` / `KOD ` öneki var (İBB'nin iç kodu ada
    ///    sızmış); atılır.
    /// 2. Bazı DÖNÜŞ güzergahları yanlışlıkla `yon = GİDİŞ` ile gelmiş, ama
    ///    adının sonunda "GİDİŞ"/"DÖNÜŞ" yazıyor. Ada güvenilir: yön oradan
    ///    alınır ve o kelime addan çıkarılır (yön ayrıca gösteriliyor).
    ///
    /// Örnek: ("kod_öksüzler - bergama dönüş", "GİDİŞ") → ad "öksüzler - bergama",
    /// yön "DÖNÜŞ".
    public static func clean(
        ad rawAd: String,
        yon rawYon: String,
        points: [Coordinate],
        boardable: [Bool]? = nil
    ) -> HatGeom {
        var ad = droppingKodPrefix(rawAd.dartTrimmed())
        var yon = rawYon.dartTrimmed()

        // Sondaki yön kelimesi (yalın ya da parantezli). Adın taşıdığı yön
        // doğru kabul edilir; `yon` alanı yanlış olabiliyor.
        var tokens = ad.dartSplitOnWhitespace()
        if let last = tokens.last, let direction = direction(of: last) {
            tokens.removeLast()
            ad = tokens.joined(separator: " ").dartTrimmed()
            yon = direction
        }

        // Arta kalan " -" / "–" kuyrukları.
        let tail = ad.unicodeScalars.reversed().prefix { $0.properties.isWhitespace || $0 == "-" || $0 == "–" }
        ad = String(ad.unicodeScalars.dropLast(tail.count)).dartTrimmed()

        return HatGeom(ad: ad, yon: yon, points: points, boardable: boardable)
    }

    /// Baştaki `kod` + en az bir `_`/boşluk önekini atar (büyük/küçük harf
    /// ayırmadan; "kod" ASCII olduğu için Türkçe I/İ sorunu yok).
    private static func droppingKodPrefix(_ ad: String) -> String {
        let scalars = ad.unicodeScalars
        let isKod = zip(scalars.prefix(3), "kod".unicodeScalars)
            .map { $0.isASCII && $0.value | 0x20 == $1.value }
        guard isKod == [true, true, true] else { return ad }
        let rest = scalars.dropFirst(3)
        let separators = rest.prefix { $0 == "_" || $0.properties.isWhitespace }
        guard !separators.isEmpty else { return ad }
        return String(rest.dropFirst(separators.count))
    }

    /// Bir sözcük yön mü ("GİDİŞ", "(dönüş)"…)? Öyleyse standart yazımı.
    private static func direction(of token: String) -> String? {
        let bare = String(token.unicodeScalars.filter { $0 != "(" && $0 != ")" })
        switch trNorm(bare.dartTrimmed()) {
        case "gidis": return "GİDİŞ"
        case "donus": return "DÖNÜŞ"
        default: return nil
        }
    }
}
