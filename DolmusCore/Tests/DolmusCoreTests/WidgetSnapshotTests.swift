import Foundation
import Testing
@testable import DolmusCore

/// Widget özeti: uygulamadaki yol tarifiyle aynı sonuç, küçük boyut, yön kuralı.
@Suite struct WidgetSnapshotTests {
    private static func place(_ query: String, _ data: DolmusData) throws -> PlacePoint {
        try #require(data.placeMatches(query, limit: 1, near: Coordinate(latitude: 38.4237, longitude: 27.1428)).first)
    }

    @Test("Ev ↔ İş: uygulamadaki yol tarifinin ilk iki seçeneği")
    func commuteMatchesPlanner() async throws {
        let data = try await Bundled.data.value
        let planner = await JourneyPlanner.build(from: data)
        let home = try Self.place("bornova metro", data)
        let work = try Self.place("şirinyer", data)
        let snapshot = WidgetSnapshot.make(data: data, planner: planner, home: home, work: work, favoriteHatIDs: [])

        for (commute, from, to) in [(snapshot.toWork, home, work), (snapshot.toHome, work, home)] {
            let commute = try #require(commute)
            let journeys = await planner.planTrip(from: from.coordinate, to: to.coordinate, data: data)
            #expect(commute.fromLabel == from.label && commute.toLabel == to.label)
            #expect(commute.options.count == min(2, journeys.count))
            for (option, journey) in zip(commute.options, journeys) {
                #expect(option.minutes == journey.estimatedMinutes)
                #expect(option.transfers == journey.transfers)
                #expect(option.feeLabel == journey.feeLabel)
                #expect(option.steps.count == journey.legs.count)
            }
        }
    }

    @Test("Adres eksikse tarif yok; favoriler sırasıyla, bilinmeyen atlanır")
    func missingPlacesAndFavorites() async throws {
        let data = try await Bundled.data.value
        let planner = await JourneyPlanner.build(from: data)
        let ids = Array(data.hats.prefix(3).map(\.id))
        let snapshot = WidgetSnapshot.make(
            data: data, planner: planner, home: try Self.place("konak", data), work: nil,
            favoriteHatIDs: [ids[2], "YOK", ids[0]]
        )
        #expect(snapshot.toWork == nil && snapshot.toHome == nil)
        #expect(snapshot.hasHome && !snapshot.hasWork)
        #expect(snapshot.favorites.map(\.id) == [ids[2], ids[0]])
        #expect(snapshot.catalog.count == data.hats.count)
    }

    @Test("JSON'a gidip gelir ve küçük kalır")
    func codableAndSmall() async throws {
        let data = try await Bundled.data.value
        let planner = await JourneyPlanner.build(from: data)
        let snapshot = WidgetSnapshot.make(
            data: data, planner: planner,
            home: try Self.place("bornova metro", data), work: try Self.place("şirinyer", data),
            favoriteHatIDs: data.hats.prefix(8).map(\.id)
        )
        let encoded = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(WidgetSnapshot.self, from: encoded) == snapshot)
        #expect(encoded.count < 64_000, "özet \(encoded.count) bayt")
    }

    @Test("Yön: 04:00–13:59 İşe, sonrası Eve; sıradaki değişim")
    func direction() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)))
        }
        #expect(CommuteDirection.automatic(at: try at(29, 3, 59), calendar: calendar) == .toHome)
        #expect(CommuteDirection.automatic(at: try at(29, 4), calendar: calendar) == .toWork)
        #expect(CommuteDirection.automatic(at: try at(29, 13, 59), calendar: calendar) == .toWork)
        #expect(CommuteDirection.automatic(at: try at(29, 14), calendar: calendar) == .toHome)
        #expect(CommuteDirection.nextSwitch(after: try at(29, 9), calendar: calendar) == (try at(29, 14)))
        #expect(CommuteDirection.nextSwitch(after: try at(29, 14), calendar: calendar) == (try at(30, 4)))
        #expect(CommuteDirection.nextSwitch(after: try at(29, 23, 30), calendar: calendar) == (try at(30, 4)))
        #expect(CommuteDirection.toWork.opposite == .toHome)
    }

    @Test("Elle seçim: sıradaki otomatik değişime kadar geçerli, ⇄ gösterilenin tersini seçer")
    func manualOverride() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)))
        }
        // 20:00'de otomatik yön Eve; ⇄ → İşe, ertesi 04:00'e kadar.
        let evening = try at(29, 20)
        let toggled = CommuteOverride.toggled(from: nil, at: evening, calendar: calendar)
        #expect(toggled == CommuteOverride(direction: .toWork, until: try at(30, 4)))
        #expect(CommuteOverride.direction(at: try at(29, 23), override: toggled, calendar: calendar) == .toWork)
        // Süresi dolunca yine saate göre: 04:00'te İşe (otomatik), 14:00'te Eve.
        #expect(CommuteOverride.direction(at: try at(30, 4), override: toggled, calendar: calendar) == .toWork)
        #expect(CommuteOverride.direction(at: try at(30, 15), override: toggled, calendar: calendar) == .toHome)
        // İkinci ⇄ yeniden Eve'ye çevirir.
        let again = CommuteOverride.toggled(from: toggled, at: try at(29, 21), calendar: calendar)
        #expect(CommuteOverride.direction(at: try at(29, 21, 1), override: again, calendar: calendar) == .toHome)
        #expect(CommuteOverride.direction(at: evening, override: nil, calendar: calendar) == .toHome)
    }
}
