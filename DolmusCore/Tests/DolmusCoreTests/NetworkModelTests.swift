import Foundation
import Testing
@testable import DolmusCore

/// Endpoint tarifleri ve cevap modelleri: ağa çıkmadan, gerçek cevap örnekleriyle.
@Suite struct NetworkModelTests {
    @Test("Ücret satırı çözülür; bozuk alan satırı atmaz, yalnızca boş sayılır")
    func decodesFareRows() throws {
        let json = """
            [{"tanim":"-","ucret":40.00,"aciklama":"GEDİZ-ÜLKÜ SİNEMASI"},
             {"tanim":"-","ucret":52.5,"aciklama":"  BUCA-OTOGAR "},
             {"tanim":"-","ucret":0,"aciklama":"İNDİ-BİNDİ"},
             {"tanim":"-","ucret":"45","aciklama":null},
             {"tanim":"-"}]
            """
        let rows = try FaresEndpoint(code: "M41").decode(Data(json.utf8))
        #expect(rows == [
            FareRow(name: "GEDİZ-ÜLKÜ SİNEMASI", fee: 40),
            FareRow(name: "BUCA-OTOGAR", fee: 53),
            FareRow(name: "İNDİ-BİNDİ", fee: nil),
            FareRow(name: "", fee: nil),
            FareRow(name: "", fee: nil),
        ])
    }

    @Test("Önbelleğe yazılan ücret tablosu aynen geri okunur")
    func fareTableRoundTrips() throws {
        let table: FareTable = ["M41": [FareRow(name: "GEDİZ-OTOGAR", fee: 60), FareRow(name: "X", fee: nil)]]
        let data = try JSONEncoder().encode(table)
        #expect(try JSONDecoder().decode(FareTable.self, from: data) == table)
    }

    @Test("Hat kodundaki Türkçe harfler adreste yüzde kodlanır", arguments: [
        ("M41", "https://minibusguzergahlari.izmir.bel.tr/api/minibus/ucretler/M41"),
        ("ÖDM05", "https://minibusguzergahlari.izmir.bel.tr/api/minibus/ucretler/%C3%96DM05"),
        ("ALĞ01", "https://minibusguzergahlari.izmir.bel.tr/api/minibus/ucretler/AL%C4%9E01"),
    ])
    func encodesFareURL(code: String, expected: String) {
        #expect(FaresEndpoint(code: code).url.absoluteString == expected)
    }

    @Test("Hava durumu: Open-Meteo cevabı ve görünümü")
    func decodesWeather() throws {
        let json = #"{"latitude":38.42,"current_units":{"temperature_2m":"°C"},"current":{"time":"2026-10-15T11:00","interval":900,"temperature_2m":19.6,"weather_code":61}}"#
        let weather = try WeatherEndpoint(coordinate: Coordinate(latitude: 38.4237, longitude: 27.1428)).decode(Data(json.utf8))
        #expect(weather == WeatherInfo(temperature: 19.6, code: 61))
        #expect(weather.temperatureLabel == "20°")
        #expect(weather.look.title == "Yağmurlu")
        #expect(WeatherInfo(temperature: -0.4, code: 2).temperatureLabel == "0°")
        #expect(WeatherInfo(temperature: 9, code: 99).look.title == "Gök gürültülü")
    }

    @Test("Hava durumu adresi üç ondalıkla")
    func weatherURL() {
        let url = WeatherEndpoint(coordinate: Coordinate(latitude: 38.4237, longitude: 27.1428)).url
        #expect(url.absoluteString == "https://api.open-meteo.com/v1/forecast?latitude=38.424&longitude=27.143&current=temperature_2m,weather_code")
    }

    @Test("Geri bildirim formu: POST, form kodlaması, gövde")
    func feedbackRequest() throws {
        let endpoint = FeedbackEndpoint(text: "Hat: M41 — A&B\n1+1 ğ")
        #expect(endpoint.method == .post)
        #expect(endpoint.headers["Content-Type"] == "application/x-www-form-urlencoded")
        let body = try #require(endpoint.body.map { String(decoding: $0, as: UTF8.self) })
        #expect(body == "entry.66917862=Hat%3A%20M41%20%E2%80%94%20A%26B%0A1%2B1%20%C4%9F")
    }

    @Test("Geri bildirim metni Android'dekiyle aynı satırlar")
    func feedbackMessage() throws {
        let date = try #require(EventDate.parse("2026-10-15T14:03:12"))
        let feedback = HatFeedback(routeIsCorrect: true, feesAreCurrent: nil, note: "  Son durak taşındı \n")
        #expect(feedback.message(hatID: "M41", hatName: "GEDİZ - IŞIKKENT", platform: "iOS 27.0", date: date) == """
            Hat: M41 — GEDİZ - IŞIKKENT
            Güzergah doğru mu?: Evet
            Ücretler güncel mi?: —
            Not: Son durak taşındı
            Tarih: 2026-10-15T14:03:12+03:00
            Platform: iOS 27.0
            """)
        #expect(HatFeedback().isEmpty)
        #expect(!HatFeedback(feesAreCurrent: false).isEmpty)
    }
}

/// Etkinlik listesinin çözümü, tarihleri, etiketleri ve filtreleri.
@Suite struct EventTests {
    /// İstanbul saatiyle bir an.
    static func istanbul(_ text: String) -> Date {
        EventDate.parse(text)!
    }

    @Test("Tarih biçimleri: UTC, saat dilimsiz (İzmir saati), kesirli, ofsetli, yalnızca gün", arguments: [
        ("2026-10-15T17:30:00Z", "2026-10-15T17:30:00Z"),
        ("2025-12-11T18:00:00", "2025-12-11T15:00:00Z"),
        ("2026-10-15T08:12:42.895330+00:00", "2026-10-15T08:12:42Z"),
        ("2026-10-15T20:30:00+03:00", "2026-10-15T17:30:00Z"),
        ("2026-10-15 20:30", "2026-10-15T17:30:00Z"),
        ("2026-10-15", "2026-10-14T21:00:00Z"),
    ])
    func parsesDates(text: String, utc: String) throws {
        let date = try #require(EventDate.parse(text))
        #expect(EventDate.format(date) == utc)
    }

    @Test("Bozuk tarih nil", arguments: ["", "yarın", "2026-02-31T10:00:00", "2026-10-15T20:30:00+3", "15.10.2026"])
    func rejectsDates(text: String) {
        #expect(EventDate.parse(text) == nil)
    }

    @Test("Liste çözülür; başlıksız ve bozuk elemanlar atlanır")
    func decodesFeed() throws {
        let json = """
            {"updated":"2026-10-15T08:12:42.895330+00:00","count":5,"events":[
              {"id":"tm1","source":"ticketmaster","title":" Duman ","category":"Music","start":"2026-10-16T17:30:00Z",
               "venue":"KüçükÇiftlik Park","city":"İzmir","lat":38.43,"lng":27.14,"image":"https://example.com/a.jpg",
               "url":"https://example.com","desc":null,"genre":"Rock","price_min":null,"price_max":null,"currency":null},
              {"id":"bos","source":"ibb","title":"   "},
              42,
              {"id":"ibb1","source":"ibb","title":"SERGİ: Kent Belleği","category":"SERGİ","start":"2025-12-11T18:00:00",
               "end":"2026-12-13T18:00:00","venue":"","lat":null,"lng":27.1,"image":"","price_min":350,"price_max":"900"},
              {"title":"Kimliksiz"}
            ]}
            """
        let feed = try EventsEndpoint().decode(Data(json.utf8))
        try #require(feed.events.count == 3)

        let concert = feed.events[0]
        #expect(concert.id == "tm1")
        #expect(concert.title == "Duman")
        #expect(concert.kind == .music)
        #expect(concert.coordinate == Coordinate(latitude: 38.43, longitude: 27.14))
        #expect(concert.imageURL == URL(string: "https://example.com/a.jpg"))
        #expect(concert.details == nil)

        let exhibition = feed.events[1]
        #expect(exhibition.start == Self.istanbul("2025-12-11T18:00:00"))
        #expect(exhibition.end == Self.istanbul("2026-12-13T18:00:00"))
        #expect(exhibition.venue == nil)
        #expect(exhibition.coordinate == nil)
        #expect(exhibition.imageURL == nil)
        #expect(exhibition.priceMin == 350)
        #expect(exhibition.priceMax == nil)

        #expect(feed.events[2].id == "|Kimliksiz|0.0")
    }

    @Test("Düz dizi biçimi de okunur")
    func decodesBareArray() throws {
        let feed = try EventsEndpoint().decode(Data(#"[{"id":"a","title":"A"},{"id":"b","title":"B"}]"#.utf8))
        #expect(feed.events.map(\.id) == ["a", "b"])
    }

    @Test("Önbelleğe yazılan liste aynı etkinlikleri verir")
    func feedRoundTrips() throws {
        let event = EventItem(
            id: "tm1", source: "ticketmaster", title: "Duman", category: "Music",
            start: Self.istanbul("2026-10-16T20:30:00"), end: nil, venue: "KüçükÇiftlik Park",
            coordinate: Coordinate(latitude: 38.43, longitude: 27.14), imageURL: URL(string: "https://example.com/a.jpg"),
            genre: "Rock", details: "Açıklama", priceMin: 350, priceMax: 900.5, currency: "TRY"
        )
        let data = try JSONEncoder().encode(EventFeed(events: [event, EventItem(id: "x", source: "ibb", title: "X")]))
        let decoded = try JSONDecoder().decode(EventFeed.self, from: data)
        #expect(decoded.events == [event, EventItem(id: "x", source: "ibb", title: "X")])
    }

    @Test("Türü kovalara ayırır", arguments: [
        ("Music", .music), ("KONSER", .music), ("Arts & Theatre", .stage),
        ("TİYATRO", .stage), ("Stand-up", .stage), ("SERGİ", .other), ("Miscellaneous", .other), (nil, .other),
    ] as [(String?, EventCategory)])
    func bucketsCategories(raw: String?, expected: EventCategory) {
        #expect(EventCategory(rawCategory: raw) == expected)
    }

    @Test("Tarih, tür ve fiyat etiketleri")
    func labels() {
        let concert = EventItem(
            id: "1", source: "ticketmaster", title: "Duman", category: "Music",
            start: EventDate.parse("2026-10-16T17:30:00Z"), genre: "Rock", priceMin: 350, priceMax: 900
        )
        #expect(concert.shortDateLabel == "Cum 16 Eki · 20:30")
        #expect(concert.longDateLabel == "Cuma, 16 Ekim · 20:30")
        #expect(concert.categoryLabel == "Konser · Rock")
        #expect(concert.priceLabel == "350–900 TL")
        #expect(concert.sourceName == "Ticketmaster (Biletix)")

        let exhibition = EventItem(
            id: "2", source: "ibb", title: "Sergi", category: "SERGİ",
            start: EventDate.parse("2026-11-01"), priceMax: 12.5, currency: "EUR"
        )
        #expect(exhibition.shortDateLabel == "Paz 1 Kas")
        #expect(exhibition.categoryLabel == "SERGİ")
        #expect(exhibition.priceLabel == "12.5 EUR")
        #expect(exhibition.sourceName == "İzmir Büyükşehir Belediyesi")
        #expect(EventItem(id: "3", source: "x", title: "Maç", category: "Sports").categoryLabel == "Spor")
        #expect(EventItem(id: "4", source: "x", title: "Tarihsiz").shortDateLabel == nil)
    }

    @Test("Filtre: geçmiştekiler gizlenir, tür/mekan/tarih/arama, başlangıca göre sıralı")
    func filters() {
        let now = Self.istanbul("2026-10-15T14:00:00")
        func event(_ id: String, _ start: String?, _ category: String = "Music", venue: String? = "Arena", title: String? = nil) -> EventItem {
            EventItem(id: id, source: "x", title: title ?? id, category: category, start: start.map(Self.istanbul), venue: venue)
        }
        let events = [
            event("dun", "2026-10-14T21:00:00"),
            event("bugun-sabah", "2026-10-15T09:00:00"),
            event("yarin", "2026-10-16T20:30:00", "Arts & Theatre", venue: "Sahne"),
            event("tarihsiz", nil),
            event("hafta-sonu", "2026-10-22T20:00:00", title: "İzmir Caz Günleri"),
            event("ay-icinde", "2026-11-15T20:00:00", "SERGİ", venue: nil),
            event("ay-disi", "2026-11-16T20:00:00"),
        ]
        var filter = EventFilter()
        #expect(filter.apply(to: events, now: now).map(\.id) == ["bugun-sabah", "yarin", "hafta-sonu", "ay-icinde", "ay-disi", "tarihsiz"])

        filter.dates = .today
        #expect(filter.apply(to: events, now: now).map(\.id) == ["bugun-sabah", "tarihsiz"])
        filter.dates = .week
        #expect(filter.apply(to: events, now: now).map(\.id) == ["bugun-sabah", "yarin", "hafta-sonu", "tarihsiz"])
        filter.dates = .month
        #expect(filter.apply(to: events, now: now).map(\.id) == ["bugun-sabah", "yarin", "hafta-sonu", "ay-icinde", "tarihsiz"])

        filter = EventFilter()
        filter.kinds = [.stage, .other]
        #expect(filter.apply(to: events, now: now).map(\.id) == ["yarin", "ay-icinde"])

        filter = EventFilter()
        filter.venues = ["Sahne"]
        #expect(filter.apply(to: events, now: now).map(\.id) == ["yarin"])
        #expect(filter.isActive)

        filter = EventFilter()
        filter.query = "izmir caz"
        #expect(filter.apply(to: events, now: now).map(\.id) == ["hafta-sonu"])
        #expect(!filter.isActive)

        #expect(EventFilter.venues(in: events) == ["Arena", "Sahne"])
    }
}
