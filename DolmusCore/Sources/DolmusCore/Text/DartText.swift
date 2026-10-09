import Foundation

// Flutter (Dart) tarafıyla aynı sonucu vermesi gereken metin işlemleri.
//
// Dart `String`'i UTF-16 kod birimi dizisidir: `==`, `contains`, `compareTo`
// ve `length` kod birimlerine bakar. Swift `String`'i ise yazı birimleriyle
// (grapheme cluster) çalışır ve Unicode eşdeğerliğini gözetir ("e" + birleşen
// aksan ile hazır "é" eşit sayılır). Veride birleşen işaretli adlar var; iki
// uygulama aynı sonucu versin diye karşılaştırma ve aramalar burada Dart
// kurallarıyla yapılır. Bayt düzeyinde arama aynı zamanda çok daha hızlıdır.
//
// Boşluk tanımı Unicode `White_Space`'tir; Dart'ınkinden yalnızca veride
// bulunmayan U+0085 ve U+FEFF'te ayrılır.
extension String {
    /// Dart `==`: kod birimleri birebir aynı mı.
    func dartEquals(_ other: String) -> Bool {
        utf8.elementsEqual(other.utf8)
    }

    /// Dart `startsWith`.
    func dartHasPrefix(_ prefix: String) -> Bool {
        utf8.starts(with: prefix.utf8)
    }

    /// Dart `contains`: alt diziyi kod birimi düzeyinde arar.
    ///
    /// Geçerli Unicode metinde UTF-8 bayt araması, UTF-16 kod birimi aramasıyla
    /// aynı sonucu verir.
    func dartContains(_ needle: String) -> Bool {
        let found = utf8.withContiguousStorageIfAvailable { haystack in
            needle.utf8.withContiguousStorageIfAvailable { needle in
                if needle.isEmpty { return true }
                if haystack.count < needle.count { return false }
                return memmem(haystack.baseAddress, haystack.count, needle.baseAddress, needle.count) != nil
            }
        }
        // Bitişik belleği olmayan (NSString'den köprülenmiş) dizgiler için yavaş yol.
        return (found ?? nil) ?? utf8.contains(needle.utf8)
    }

    /// Dart `compareTo` sırası: UTF-16 kod birimlerine göre sözlük sırası.
    func dartPrecedes(_ other: String) -> Bool {
        utf16.lexicographicallyPrecedes(other.utf16)
    }

    /// Dart `length`.
    var dartLength: Int { utf16.count }

    /// Dart `trim()`.
    func dartTrimmed() -> String {
        let scalars = unicodeScalars
        guard let first = scalars.firstIndex(where: { !$0.properties.isWhitespace }),
              let last = scalars.lastIndex(where: { !$0.properties.isWhitespace })
        else { return "" }
        return String(scalars[first...last])
    }

    /// Dart `split(RegExp(r'\s+'))`: boşluk öbeklerinden böler. Baştaki ya da
    /// sondaki boşluk, Dart'taki gibi boş bir parça bırakır.
    func dartSplitOnWhitespace() -> [String] {
        var pieces: [String] = []
        var current = String.UnicodeScalarView()
        var inWhitespace = false
        for scalar in unicodeScalars {
            if scalar.properties.isWhitespace {
                if !inWhitespace {
                    pieces.append(String(current))
                    current = String.UnicodeScalarView()
                    inWhitespace = true
                }
            } else {
                current.append(scalar)
                inWhitespace = false
            }
        }
        pieces.append(String(current))
        return pieces
    }
}
