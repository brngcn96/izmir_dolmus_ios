import Testing
@testable import DolmusCore

@Suite struct SpokenLabelsTests {
    @Test(arguments: [
        ("40–65 ₺", "40 ile 65 lira arası"),
        ("50 ₺", "50 lira"),
        ("Ücret ?", "ücret bilinmiyor"),
        ("—", "ücret bilinmiyor"),
    ])
    func fee(label: String, spoken: String) {
        #expect(label.spokenFee == spoken)
    }

    @Test(arguments: [
        ("~350 m", "yaklaşık 350 metre"),
        ("350 m", "350 metre"),
        ("1,2 km", "1,2 kilometre"),
        ("~1,2 km", "yaklaşık 1,2 kilometre"),
        ("yakın", "yakın"),
    ])
    func distance(label: String, spoken: String) {
        #expect(label.spokenDistance == spoken)
    }

    @Test("Uygulamanın gerçek ücret etiketleri")
    func realFeeLabels() async throws {
        let data = try await Bundled.data.value
        for hat in data.hats {
            let spoken = hat.feeLabel.spokenFee
            #expect(!spoken.contains("₺") && !spoken.contains("–"), "\(hat.feeLabel)")
        }
    }
}
