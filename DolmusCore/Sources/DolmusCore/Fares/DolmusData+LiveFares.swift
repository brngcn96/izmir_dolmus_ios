extension DolmusData {
    /// Ücret servisinde sorulacak hat kodları: tekrarsız, hat listesindeki
    /// sırayla. Bölünmüş hatlar ana hattın kodunu paylaşır.
    public var fareCodes: [String] {
        var seen: Set<String> = []
        return hats.map(\.apiCode).filter { seen.insert($0).inserted }
    }

    /// Canlı ücretleri veri dosyasındaki ücretlerin üstüne bindirilmiş kopya.
    ///
    /// Her hattın satırları kendi `apiCode`'unun cevabıyla, adları `trNorm`'dan
    /// geçirilerek eşlenir. Eşleşmeyen ya da servisin ücret vermediği satırda
    /// dosyadaki ücret kalır. Sonuç yalnızca dosyadaki veriye ve tabloya bağlıdır:
    /// aynı tabloyla iki kez uygulamak bir kez uygulamakla aynıdır.
    public func applyingLiveFares(_ table: FareTable) -> DolmusData {
        // Her kodun satırları bir kez normalize edilir; bölünmüş hatlar paylaşır.
        let feesByCode = table.mapValues(Self.feesByName)
        var copy = self
        copy.hats = hats.map { $0.applyingLiveFares(feesByCode[$0.apiCode] ?? [:]) }
        // İlçelerdeki hatlar aynı hatların kopyası: yeniden hesaplanmaz, güncel hali alınır.
        copy.districts = districts.map { district in
            var district = district
            district.hats = district.hats.map { copy.hat(id: $0.id) ?? $0 }
            return district
        }
        return copy
    }

    /// `trNorm`'lu ad → ücret. Aynı ada birden çok satır gelirse ilki geçerli
    /// (Flutter'daki `putIfAbsent`).
    static func feesByName(_ rows: [FareRow]) -> [String: Int?] {
        var fees: [String: Int?] = [:]
        for row in rows {
            let key = trNorm(row.name)
            // `fees[key] = nil` anahtarı silerdi; `nil` ücreti saklamak için `updateValue`.
            if fees.index(forKey: key) == nil {
                fees.updateValue(row.fee, forKey: key)
            }
        }
        return fees
    }
}

extension DolmusHat {
    /// Satırların `liveFee`'si `feeByName`'den; adı yoksa `nil` (dosyadaki ücret).
    func applyingLiveFares(_ feeByName: [String: Int?]) -> DolmusHat {
        // Tabloda bu hat yok ve önceden de canlı ücreti yoksa değişecek bir şey yok.
        if feeByName.isEmpty, !segments.contains(where: { $0.liveFee != nil }) {
            return self
        }
        var copy = self
        copy.segments = segments.map { segment in
            var segment = segment
            segment.liveFee = feeByName[trNorm(segment.name)] ?? nil
            return segment
        }
        return copy
    }
}
