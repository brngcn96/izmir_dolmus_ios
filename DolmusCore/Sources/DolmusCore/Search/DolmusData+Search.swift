extension DolmusData {
    /// Hat araması. Sorgu boşsa tüm hatlar (ada göre); doluysa her kelimesi
    /// hat adında ya da kilit noktalarından birinde geçen hatlar.
    ///
    /// Sıra: tam ifade adda geçenler, sonra tüm kelimeleri adda geçenler,
    /// sonra kilit noktalarından bulunanlar; her öbek kendi içinde ada göre.
    public func searchHats(_ query: String) -> [DolmusHat] {
        let phrase = trNorm(query)
        if phrase.isEmpty { return hats }
        // Kısaltmalar genişler: "cd" → "caddesi".
        let tokens = queryTokens(query)

        var hits: [(index: Int, rank: Int)] = []
        for (index, hat) in hats.enumerated() {
            let name = hatNameNorms[index]
            let allTokensInName = tokens.allSatisfy(name.dartContains)
            let matches = allTokensInName || tokens.allSatisfy { token in
                name.dartContains(token)
                    || hat.segments.contains { $0.stopsNorm.contains { $0.dartContains(token) } }
            }
            guard matches else { continue }
            let rank = name.dartContains(phrase) ? 0 : (allTokensInName ? 1 : 2)
            hits.append((index, rank))
        }
        // `hats` zaten ada göre sıralı; kararlı sıralama öbek içinde o sırayı korur.
        return hits.sorted { $0.rank < $1.rank }.map { hats[$0.index] }
    }

    /// Yer araması: yer sözlüğünde ve önemli noktalarda, sorgunun her kelimesi
    /// adında geçen yerler. Nereden → Nereye uçlarını ve "buradan geçen hatlar"
    /// önerisini çözmek için. Sorgu 3 harften kısaysa boş döner.
    ///
    /// Sıra: önce yerler (okul, hastane, metro…), ESHOT durakları en sonda;
    /// ardından metin uyumu (tam ad, adın başı, adın içi, dağınık kelimeler),
    /// `near`'a yakınlık ve kısa ad. Aynı addan en çok iki sonuç gelir.
    ///
    /// - Parameter near: Eşit uyumdaki sonuçlar bu noktaya yakınlığa göre
    ///   sıralanır; uygulamada haritanın o anki merkezi.
    public func placeMatches(_ query: String, limit: Int = 3, near: Coordinate? = nil) -> [PlacePoint] {
        let phrase = trNorm(query)
        guard phrase.dartLength >= 3 else { return [] }
        let tokens = queryTokens(query)

        struct Hit {
            let place: PlacePoint
            let isStop: Bool
            let textRank: Int
            let distance: Double
            let labelLength: Int
        }

        func hit(_ place: PlacePoint, norm: String, isStop: Bool) -> Hit? {
            guard tokens.allSatisfy(norm.dartContains) else { return nil }
            let textRank = if norm.dartEquals(phrase) { 0 }
                else if norm.dartHasPrefix(phrase) { 1 }
                else if norm.dartContains(phrase) { 2 }
                else { 3 }
            // Yaklaşık uzaklığın karesi (derece). İzmir küçük bir alan; sıralama
            // için boylamı sabit bir katsayıyla düzeltmek yeterli.
            var distance = 0.0
            if let near {
                let dy = place.coordinate.latitude - near.latitude
                let dx = (place.coordinate.longitude - near.longitude) * 0.8
                distance = dy * dy + dx * dx
            }
            return Hit(
                place: place,
                isStop: isStop,
                textRank: textRank,
                distance: distance,
                labelLength: place.label.dartLength
            )
        }

        var hits: [Hit] = []
        for (index, place) in duraklar.enumerated() {
            if let hit = hit(place, norm: durakNorms[index], isStop: durakIsStop[index]) {
                hits.append(hit)
            }
        }
        // Önemli noktalar durak sayılmaz; sıralamada durakların önüne geçer.
        for (index, landmark) in landmarks.enumerated() {
            let place = PlacePoint(label: landmark.name, coordinate: landmark.coordinate)
            if let hit = hit(place, norm: landmarkNorms[index], isStop: false) {
                hits.append(hit)
            }
        }

        hits.sort { a, b in
            if a.isStop != b.isStop { return !a.isStop }
            if a.textRank != b.textRank { return a.textRank < b.textRank }
            if a.distance != b.distance { return a.distance < b.distance }
            return a.labelLength < b.labelLength
        }

        // Aynı addan ("Benzinlik", "Cami"…) onlarca durak olabiliyor; hepsi eşit
        // sırada gelip listeyi doldurmasın diye ad başına en çok iki sonuç.
        // Aynı noktadaki mükerrer kayıtlar da elenir.
        let maxPerName = 2
        var seenCoordinates: Set<Coordinate> = []
        var countByName: [String: Int] = [:]
        var results: [PlacePoint] = []
        for hit in hits {
            guard seenCoordinates.insert(hit.place.coordinate).inserted else { continue }
            let baseName = trNorm(String(hit.place.label.unicodeScalars.prefix { $0 != "·" }))
            let count = countByName[baseName, default: 0]
            guard count < maxPerName else { continue }
            countByName[baseName] = count + 1
            results.append(hit.place)
            if results.count >= limit { break }
        }
        return results
    }

    /// Yer adından tür (arama sonucunda ibare göstermek için): `durak`, `okul`,
    /// `hastane`, `cadde`, `mahalle`, `pazar`, `eczane`.
    public static func placeKind(of label: String) -> String {
        PlaceClassifier.kind(of: label)
    }
}
