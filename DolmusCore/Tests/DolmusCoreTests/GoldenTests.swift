import Foundation
import Testing
@testable import DolmusCore

/// Portların Flutter uygulamasıyla aynı sonucu verdiğinin kanıtı: gerçek veri
/// yüklenir, sonuçlar Flutter'ın gerçek kodundan üretilmiş beklenen çıktılarla
/// (`Golden/`) karşılaştırılır.
///
/// Bir test kırılırsa önce `Golden/SOURCE`'a bak: Flutter tarafında kod ya da
/// veri değiştiyse `Scripts/sync-data.sh` ve `Scripts/export-golden.sh`
/// çalıştırılır; değişmediyse hata bu taraftaki porttadır.
@Suite("Altın dosyalar: Flutter ile aynı sonuç")
struct GoldenTests {
    // MARK: Hatlar

    struct HatSummary: Decodable, Equatable {
        let id: String
        let name: String
        let apiCode: String
        let ilce: String?
        let feeLabel: String
        let segments: [String]
        let keyStops: Int
        let keyStopsHash: String
        let info: String?

        init(_ hat: DolmusHat) {
            id = hat.id
            name = hat.name
            apiCode = hat.apiCode
            ilce = hat.ilce
            feeLabel = hat.feeLabel
            segments = hat.segments.map(\.id)
            keyStops = hat.keyStopNames.count
            keyStopsHash = fnv(hat.keyStopNames)
            info = hat.info
        }
    }

    @Test("Hat listesi: düzeltme kuralları, sıra, ücret etiketi, satırlar")
    func hats() async throws {
        let data = try await Bundled.data.value
        let expected: [HatSummary] = try Golden.load("hats.json")
        expectSame(data.hats.map(HatSummary.init), flutter: expected, "hats")
    }

    // MARK: Güzergah çizgileri

    struct GeomSummary: Decodable, Equatable {
        let ad: String
        let yon: String
        let n: Int
        let boardable: Int
        let boardHash: String
        let first: [Double]
        let last: [Double]

        init(_ geom: HatGeom) {
            ad = geom.ad
            yon = geom.yon
            n = geom.points.count
            boardable = geom.boardable.count(where: \.self)
            boardHash = fnv([geom.boardable.map { $0 ? "1" : "0" }.joined()])
            first = geom.points.first.map { [$0.latitude, $0.longitude] } ?? []
            last = geom.points.last.map { [$0.latitude, $0.longitude] } ?? []
        }
    }

    struct HatGeoms: Decodable {
        let hat: String
        let geoms: [GeomSummary]
    }

    @Test("Güzergahlar: ad/yön temizliği, çıkarma, bölme, takas, binilebilirlik, GİDİŞ önce")
    func geoms() async throws {
        let data = try await Bundled.data.value
        let expected: [HatGeoms] = try Golden.load("geoms.json")
        var budget = FailureBudget()
        for entry in expected where !budget.isExhausted {
            budget.note(expectSame(
                data.geoms(for: entry.hat).map(GeomSummary.init),
                flutter: entry.geoms,
                "geoms(\(entry.hat))"
            ))
        }
    }

    // MARK: İlçeler

    struct DistrictSummary: Decodable, Equatable {
        let name: String
        let hats: [String]
    }

    @Test("İlçe grupları")
    func districts() async throws {
        let data = try await Bundled.data.value
        let expected: [DistrictSummary] = try Golden.load("districts.json")
        expectSame(data.districts.map(\.name), flutter: expected.map(\.name), "ilçeler")
        var budget = FailureBudget()
        for (district, expected) in zip(data.districts, expected) where !budget.isExhausted {
            budget.note(expectSame(district.hats.map(\.id), flutter: expected.hats, "ilçe \(expected.name)"))
        }
    }

    // MARK: Arama

    struct HatSearch: Decodable {
        let q: String
        let ids: [String]
    }

    @Test("Hat araması")
    func hatSearch() async throws {
        let data = try await Bundled.data.value
        let expected: [HatSearch] = try Golden.load("hat_search.json")
        var budget = FailureBudget()
        for entry in expected where !budget.isExhausted {
            budget.note(expectSame(
                data.searchHats(entry.q).map(\.id),
                flutter: entry.ids,
                "searchHats(\"\(entry.q)\")"
            ))
        }
    }

    struct PlaceSearch: Decodable {
        let q: String
        let limit: Int
        let near: Coordinate
        let results: [PlacePoint]
    }

    @Test("Yer araması")
    func placeSearch() async throws {
        let data = try await Bundled.data.value
        let expected: [PlaceSearch] = try Golden.load("place_search.json")
        var budget = FailureBudget()
        for entry in expected where !budget.isExhausted {
            budget.note(expectSame(
                data.placeMatches(entry.q, limit: entry.limit, near: entry.near),
                flutter: entry.results,
                "placeMatches(\"\(entry.q)\", limit: \(entry.limit), near: \(entry.near.latitude), \(entry.near.longitude))"
            ))
        }
    }

    // MARK: Metin

    struct TextGolden: Decodable {
        struct TokenSample: Decodable {
            let input: String
            let tokens: [String]

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                input = try container.decode(String.self)
                tokens = try container.decode([String].self)
            }
        }

        let trNorm: [[String]]
        let queryTokens: [TokenSample]
        let counts: [String: Int]
        let normHashes: [String: String]
        let kinds: [String: String]
    }

    @Test("trNorm ve queryTokens: zor örnekler")
    func textSamples() throws {
        let golden: TextGolden = try Golden.load("text.json")
        // Swift'in `==`'i Unicode eşdeğerliğine bakar ("é" ile "e" + aksan eşit
        // sayılır); Flutter ile bayt bayt aynı olsun diye UTF-8 karşılaştırılır.
        var budget = FailureBudget()
        for pair in golden.trNorm where !budget.isExhausted {
            budget.note(expectSame(
                Array(trNorm(pair[0]).utf8),
                flutter: Array(pair[1].utf8),
                "trNorm(\"\(pair[0])\") = \"\(trNorm(pair[0]))\", beklenen \"\(pair[1])\"; UTF-8"
            ))
        }
        for sample in golden.queryTokens where !budget.isExhausted {
            budget.note(expectSame(
                queryTokens(sample.input),
                flutter: sample.tokens,
                "queryTokens(\"\(sample.input)\")"
            ))
        }
    }

    @Test("trNorm: verideki bütün adlar")
    func textBulk() async throws {
        let data = try await Bundled.data.value
        let golden: TextGolden = try Golden.load("text.json")
        let routes = data.hats.flatMap(\.segments)

        #expect(data.hats.count == golden.counts["hats"])
        #expect(routes.count == golden.counts["routes"])
        #expect(data.duraklar.count == golden.counts["duraklar"])
        #expect(data.landmarks.count == golden.counts["landmarks"])

        #expect(fnv(data.hats.map { trNorm($0.name) }) == golden.normHashes["hatNames"])
        #expect(fnv(routes.map { trNorm($0.name) }) == golden.normHashes["routeNames"])
        #expect(fnv(routes.flatMap(\.stops).map(trNorm)) == golden.normHashes["stops"])
        #expect(fnv(data.duraklar.map { trNorm($0.label) }) == golden.normHashes["duraklar"])
        #expect(fnv(data.landmarks.map { trNorm($0.name) }) == golden.normHashes["landmarks"])
    }

    @Test("Yer türleri: sözlükteki ve önemli noktalardaki bütün adlar")
    func placeKinds() async throws {
        let data = try await Bundled.data.value
        let golden: TextGolden = try Golden.load("text.json")
        func letters(_ labels: [String]) -> [Character] {
            labels.map { DolmusData.placeKind(of: $0).first ?? "?" }
        }
        let duraklar = Array(try #require(golden.kinds["duraklar"]))
        let landmarks = Array(try #require(golden.kinds["landmarks"]))
        expectLabeledSame(letters(data.duraklar.map(\.label)), flutter: duraklar, labels: data.duraklar.map(\.label))
        expectLabeledSame(letters(data.landmarks.map(\.name)), flutter: landmarks, labels: data.landmarks.map(\.name))
    }

    /// Tür harflerini karşılaştırır; farkları hangi ada ait olduklarıyla bildirir.
    private func expectLabeledSame(
        _ actual: [Character],
        flutter expected: [Character],
        labels: [String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(actual.count == expected.count, sourceLocation: sourceLocation)
        let differences = zip(labels, zip(actual, expected)).filter { $0.1.0 != $0.1.1 }
        for (label, kinds) in differences.prefix(10) {
            Issue.record("\"\(label)\": Swift \(kinds.0) ≠ Flutter \(kinds.1)", sourceLocation: sourceLocation)
        }
        if differences.count > 10 {
            Issue.record("… \(differences.count - 10) fark daha", sourceLocation: sourceLocation)
        }
    }
}
