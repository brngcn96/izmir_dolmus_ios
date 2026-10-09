/// Sık kullanılan kısaltmalar → tam biçim. Kullanıcı "cd" yazınca "caddesi"
/// ile eşleşsin diye sorgu kelimeleri genişletilir.
private let tokenAliases: [String: String] = [
    "cd": "caddesi", "cad": "caddesi", "cadd": "caddesi", "cddesi": "caddesi",
    "sk": "sokak", "sok": "sokak", "sokagi": "sokak",
    "mah": "mahallesi", "mh": "mahallesi", "mahalle": "mahallesi",
    "blv": "bulvari", "bul": "bulvari", "bulv": "bulvari", "bulvar": "bulvari",
    "cami": "camii",
    "hst": "hastane", "hast": "hastane", "hastanesi": "hastane",
    "ilkokulu": "ilkokul", "ortaokulu": "ortaokul",
    "univ": "universitesi", "uni": "universitesi",
    "ist": "istasyonu", "istasyon": "istasyonu",
    "meydani": "meydan",
]

/// Sorguyu sadeleştirip kelimelere böler ve kısaltmaları genişletir.
public func queryTokens(_ query: String) -> [String] {
    trNorm(query)
        .split(separator: " ")
        .map { tokenAliases[String($0)] ?? String($0) }
}
