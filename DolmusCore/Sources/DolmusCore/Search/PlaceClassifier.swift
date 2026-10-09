/// Yer sözlüğündeki (`duraklar.json`) adlar türsüz gelir; tür ada bakılarak
/// çıkarılır: "Atatürk İlkokulu" → okul, "Şehitler Cad." → cadde.
///
/// Flutter tarafı bunu düzenli ifadelerle yapar (`repository.dart`,
/// `_classify`). Dart'ın düzenli ifadeleri ECMAScript kurallarıyla çalışır ve
/// iki noktada Unicode'dan ayrılır; iki uygulama aynı türü versin diye
/// eşleştirme burada o kurallarla, elle yapılır:
///
/// - Kelime sınırı (`\b`) yalnızca ASCII harf/rakam/alt çizgiyi kelime sayar;
///   "ı", "ğ" gibi harfler kelime dışıdır.
/// - Büyük/küçük harf ayırmadan karşılaştırma tek tek harflerin büyük haline
///   bakar ve ASCII ile ASCII dışını birbirine bağlamaz: "ı" yalnızca "ı" ile,
///   "İ" yalnızca "İ" ile eşleşir; "i" ile ikisi de eşleşmez.
enum PlaceClassifier {
    /// Öncelik sırasıyla türler: bir ad birden çok kurala uyarsa öndeki geçerlidir.
    private static let kinds = ["mahalle", "cadde", "okul", "eczane", "hastane", "pazar"]
    private static let fallbackKind = "durak"

    /// Yer adının türü: `mahalle`, `cadde`, `okul`, `eczane`, `hastane`,
    /// `pazar`; hiçbiri değilse `durak`.
    static func kind(of label: String) -> String {
        // İlçe ekinden önceki kısım: "Atatürk Caddesi · Konak" → "Atatürk Caddesi".
        let base = String(label.unicodeScalars.prefix { $0 != "·" }).dartTrimmed()
        let text = base.utf16.map(fold)

        var best = kinds.count
        for start in text.indices {
            guard let candidates = rulesByFirstUnit[text[start]] else { continue }
            for rule in candidates where rule.rank < best && rule.matches(text, at: start) {
                best = rule.rank
            }
            if best == 0 { break }
        }
        return best < kinds.count ? kinds[best] : fallbackKind
    }

    // MARK: Kurallar

    private struct Rule {
        enum Tail {
            /// Ardından ne gelirse gelsin.
            case anything
            /// Ardından kelime sınırı (`\b`) gelmeli.
            case wordBoundary
            /// Metnin sonu (`$`) olmalı.
            case endOfText
        }

        /// `kinds` içindeki sırası.
        let rank: Int
        /// Aranan metin, `fold`'dan geçmiş.
        let units: [UInt16]
        /// Önünde kelime sınırı (`\b`) gerekli mi.
        let startsAtWordBoundary: Bool
        let tail: Tail

        func matches(_ text: [UInt16], at start: Int) -> Bool {
            let end = start + units.count
            guard end <= text.count else { return false }
            for (offset, unit) in units.enumerated() where text[start + offset] != unit {
                return false
            }
            if startsAtWordBoundary, !isWordBoundary(text, start) { return false }
            switch tail {
            case .anything: return true
            case .wordBoundary: return isWordBoundary(text, end)
            case .endOfText: return end == text.count
            }
        }
    }

    private static let rulesByFirstUnit: [UInt16: [Rule]] = {
        var rules: [Rule] = []
        func add(_ kind: String, _ literals: [String], wordStart: Bool = false, tail: Rule.Tail = .anything) {
            let rank = kinds.firstIndex(of: kind)!
            for literal in literals {
                rules.append(Rule(
                    rank: rank,
                    units: literal.utf16.map(fold),
                    startsAtWordBoundary: wordStart,
                    tail: tail
                ))
            }
        }

        // (mahallesi|\bmah\.?$)
        add("mahalle", ["mahallesi"])
        add("mahalle", ["mah", "mah."], wordStart: true, tail: .endOfText)
        // \b(cadde|caddesi|cad\.?|cd\.?|sokak|sokağı|sok\.?|sk\.?|bulvar|bulvarı|blv\.?|bul\.?)\b
        add("cadde", [
            "cadde", "caddesi", "cad", "cad.", "cd", "cd.",
            "sokak", "sokağı", "sok", "sok.", "sk", "sk.",
            "bulvar", "bulvarı", "blv", "blv.", "bul", "bul.",
        ], wordStart: true, tail: .wordBoundary)
        // (ilkokulu|ortaokulu|lisesi|anaokulu|ilköğretim|koleji|okulu|meslek|imam hatip)
        add("okul", [
            "ilkokulu", "ortaokulu", "lisesi", "anaokulu", "ilköğretim",
            "koleji", "okulu", "meslek", "imam hatip",
        ])
        // eczane
        add("eczane", ["eczane"])
        // (hastane|hastanesi|tıp merkezi|sağlık oca|aile sağlığı)
        add("hastane", ["hastane", "tıp merkezi", "sağlık oca", "aile sağlığı"])
        // (pazar yeri|pazaryeri|\bpazarı?\b)
        add("pazar", ["pazar yeri", "pazaryeri"])
        add("pazar", ["pazar", "pazarı"], wordStart: true, tail: .wordBoundary)

        return Dictionary(grouping: rules, by: { $0.units[0] })
    }()

    // MARK: ECMAScript kuralları

    /// Büyük/küçük harf ayırmayan karşılaştırma için bir UTF-16 biriminin
    /// kanonik hali (ECMAScript `Canonicalize`): büyük harfi tek birimse ve
    /// ASCII dışı bir harfi ASCII'ye taşımıyorsa o, yoksa kendisi.
    private static func fold(_ unit: UInt16) -> UInt16 {
        if unit < 0x80 {
            return (0x61...0x7A).contains(unit) ? unit - 0x20 : unit
        }
        guard let scalar = Unicode.Scalar(unit) else { return unit }
        let upper = scalar.properties.uppercaseMapping.utf16
        guard upper.count == 1, let folded = upper.first, folded >= 0x80 else { return unit }
        return folded
    }

    /// `index`'in solu ile sağı arasında kelime sınırı (`\b`) var mı.
    private static func isWordBoundary(_ text: [UInt16], _ index: Int) -> Bool {
        isWordUnit(text, index - 1) != isWordUnit(text, index)
    }

    /// ASCII harf, rakam ya da alt çizgi mi. Metin `fold`'dan geçtiği için
    /// küçük harf aralığına bakmak gerekmez.
    private static func isWordUnit(_ text: [UInt16], _ index: Int) -> Bool {
        guard text.indices.contains(index) else { return false }
        switch text[index] {
        case 0x30...0x39, 0x41...0x5A, 0x5F: return true
        default: return false
        }
    }
}
