import Foundation
import Testing
@testable import DolmusCore

/// Canlı ücretlerin gerçek veriye bindirilmesi.
@Suite struct LiveFaresTests {
    @Test("Ücret kodları tekrarsız; bölünmüş hatlar ana hattın kodunu paylaşır")
    func fareCodes() async throws {
        let data = try await Bundled.data.value
        let codes = data.fareCodes
        #expect(Set(codes).count == codes.count)
        #expect(codes.count < data.hats.count)
        #expect(codes.contains("M41"))
        // İlçe listesi hatları kimlikle bulur; kimlikler tekrarsız olmalı.
        #expect(Set(data.hats.map(\.id)).count == data.hats.count)
        #expect(!codes.contains { $0.contains("#") })
    }

    @Test("Adı eşleşen satır güncel ücreti alır; eşleşmeyen ve ücretsiz satır dosyadakini korur")
    func appliesMatchingRows() async throws {
        let data = try await Bundled.data.value
        let hat = try #require(data.hat(id: "M41"))
        let table: FareTable = ["M41": [
            FareRow(name: "Gediz-Ülkü Sineması", fee: 45),       // büyük/küçük harf ve Türkçe harf farkı
            FareRow(name: "GEDİZ-ÜLKÜ SİNEMASI", fee: 99),       // aynı ad ikinci kez: ilki geçerli
            FareRow(name: "IŞIKKENT-GEDİZ", fee: nil),           // ücret yok: dosyadaki kalır
            FareRow(name: "Olmayan bir güzergah", fee: 500),
        ]]

        let live = data.applyingLiveFares(table)
        let updated = try #require(live.hat(id: "M41"))
        let segment = try #require(updated.segments.first { $0.name == "GEDİZ-ÜLKÜ SİNEMASI" })
        #expect(segment.fee == 45)
        #expect(segment.bakedFee == 40)
        #expect(updated.segments.first { $0.name == "IŞIKKENT-GEDİZ" }?.fee == 60)
        #expect(updated.segments.filter { $0.liveFee != nil }.count == 1)
        #expect(updated.segments.map(\.fee) == hat.segments.map { $0.name == "GEDİZ-ÜLKÜ SİNEMASI" ? 45 : $0.fee })
        // İlçe listesindeki kopyası da güncel.
        let inDistrict = live.districts.flatMap(\.hats).filter { $0.id == "M41" }
        #expect(!inDistrict.isEmpty)
        #expect(inDistrict.allSatisfy { $0 == updated })
        // Başka hatlar değişmez.
        #expect(live.hats.filter { $0.apiCode != "M41" } == data.hats.filter { $0.apiCode != "M41" })
    }

    @Test("Her zaman dosyadaki ücretten hesaplanır: tekrar uygulamak ve boş tablo")
    func isIdempotent() async throws {
        let data = try await Bundled.data.value
        let table: FareTable = ["M41": [FareRow(name: "GEDİZ-ÜLKÜ SİNEMASI", fee: 45)]]
        let once = data.applyingLiveFares(table)
        #expect(once.applyingLiveFares(table).hats == once.hats)
        #expect(once.applyingLiveFares([:]).hats == data.hats)
    }

    @Test("Bölünmüş hatlar ana hattın cevabından ücret alır")
    func splitHatsShareParentCode() async throws {
        let data = try await Bundled.data.value
        let split = try #require(data.hats.first { $0.id.contains("#") && !$0.segments.isEmpty })
        let table: FareTable = [split.apiCode: split.segments.map { FareRow(name: $0.name, fee: 1) }]
        let updated = try #require(data.applyingLiveFares(table).hat(id: split.id))
        #expect(updated.segments.allSatisfy { $0.fee == 1 })
    }
}

/// Diskteki önbellek.
@Suite struct FileCacheTests {
    @Test("Kaydedilen değer zamanıyla geri okunur; dosya yoksa nil")
    func roundTrips() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "FileCacheTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileCache<FareTable>(url: directory.appending(path: "alt/fares.json"))
        #expect(await cache.load() == nil)

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        try await cache.save(["M41": [FareRow(name: "A", fee: 40)]], at: date)
        let entry = try #require(await cache.load())
        #expect(entry.savedAt == date)
        #expect(entry.value == ["M41": [FareRow(name: "A", fee: 40)]])

        cache.remove()
        #expect(await cache.load() == nil)
    }
}
