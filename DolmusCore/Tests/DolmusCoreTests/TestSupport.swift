import Foundation
import Testing
@testable import DolmusCore

/// Paketle gelen gerçek veri. Yüklemesi zaman aldığı için bir kez yapılır;
/// bütün testler aynı sonucu paylaşır.
enum Bundled {
    static let data = Task { try await DataLoader().load() }
}

/// Flutter uygulamasının gerçek kodundan üretilmiş beklenen çıktılar
/// (`Golden/` klasörü; `Scripts/export-golden.sh` yazar).
enum Golden {
    static func load<T: Decodable>(_ fileName: String) throws -> T {
        let directory = try #require(Bundle.module.url(forResource: "Golden", withExtension: nil))
        let data = try Data(contentsOf: directory.appending(path: fileName))
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// FNV-1a 64: her dizginin UTF-8 baytları, ardından ayırıcı olarak 0x0A.
/// Dışa aktarımdaki (`golden_export_test.dart`) `fnv` ile aynı özeti üretir;
/// binlerce dizgi tek tek dosyaya dökülmeden karşılaştırılır.
func fnv(_ items: some Sequence<String>) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    let prime: UInt64 = 0x100_0000_01b3
    for item in items {
        for byte in item.utf8 {
            hash = (hash ^ UInt64(byte)) &* prime
        }
        hash = (hash ^ 0x0a) &* prime
    }
    let hex = String(hash, radix: 16)
    return String(repeating: "0", count: 16 - hex.count) + hex
}

/// Swift sonucunu Flutter'ın beklenen çıktısıyla karşılaştırır. Yüzlerce
/// elemanlı dizilerin tamamını dökmek yerine ilk birkaç farkı sırasıyla bildirir.
///
/// - Returns: İki dizi aynıysa `true`.
@discardableResult
func expectSame<T: Equatable>(
    _ actual: [T],
    flutter expected: [T],
    _ what: String,
    sourceLocation: SourceLocation = #_sourceLocation
) -> Bool {
    if actual == expected { return true }
    if actual.count != expected.count {
        Issue.record(
            "\(what): Swift \(actual.count) eleman, Flutter \(expected.count) eleman",
            sourceLocation: sourceLocation
        )
    }
    let differences = zip(actual, expected).enumerated().filter { $0.element.0 != $0.element.1 }
    for (index, pair) in differences.prefix(3) {
        Issue.record(
            "\(what) [\(index)]: Swift \(pair.0) ≠ Flutter \(pair.1)",
            sourceLocation: sourceLocation
        )
    }
    if differences.count > 3 {
        Issue.record("\(what): … \(differences.count - 3) fark daha", sourceLocation: sourceLocation)
    }
    return false
}

/// Çok girdili karşılaştırmalarda gürültüyü sınırlar: birkaç girdi kırıldıktan
/// sonra kalanları denemeyi bırakır.
struct FailureBudget {
    private(set) var remaining = 5

    var isExhausted: Bool { remaining <= 0 }

    mutating func note(_ passed: Bool) {
        if !passed { remaining -= 1 }
    }
}
