// Veri dosyalarının diskteki biçimi. Buradaki tipler yalnızca çözme sırasında
// yaşar; `DolmusData` bunlardan temizlenmiş modelleri kurar.

/// `routes.json`'ın kökü. Dosyadaki diğer alanlar (şema, şehir, yer listesi)
/// kullanılmıyor; `Decodable` tanımadığı anahtarları atlar.
struct RoutesFile: Decodable {
    let routes: [DolmusRoute]
}

/// `hat_geoms.json`'daki ham güzergah. Dosyanın kökü bir sözlüktür:
/// hat kodu → `[RawHatGeom]`.
struct RawHatGeom: Decodable {
    /// Temizlenmemiş ad (bkz. `HatGeom.clean`).
    let ad: String
    let yon: String?
    let pts: [Coordinate]
    /// `pts` ile aynı uzunlukta "0"/"1" dizgisi: o noktada binilebilir mi.
    /// Yoksa her nokta binilebilir sayılır.
    let board: String?
}

extension HatGeom {
    /// Ham güzergahtan: adı ve yönü temizler, binilebilirlik bayraklarını
    /// `BoardOverrides` düzeltmeleriyle birlikte kurar.
    init(raw: RawHatGeom) {
        let flags = raw.board.map { Array($0.utf8) }
        let boardable = raw.pts.enumerated().map { index, point in
            let flagged = flags.map { index < $0.count && $0[index] != UInt8(ascii: "0") } ?? true
            return (flagged || BoardOverrides.forcesBoardable(point))
                && !BoardOverrides.forcesNonBoardable(point)
        }
        self = .clean(ad: raw.ad, yon: raw.yon ?? "", points: raw.pts, boardable: boardable)
    }
}
