@Suite("trNorm")
struct TrNormTests {
    @Test("Türkçe harfleri sadeleştirir, küçültür, boşlukları toplar", arguments: [
        ("KARŞIYAKA", "karsiyaka"),
        ("Gaziemir", "gaziemir"),
        ("  Üçkuyular  ", "uckuyular"),
        ("İZMİR", "izmir"),
        ("IŞIKKENT", "isikkent"),
        ("Kâtip   Çelebi", "katip celebi"),
        ("", ""),
    ])
    func normalizes(input: String, expected: String) {
        #expect(trNorm(input) == expected)
    }
}
