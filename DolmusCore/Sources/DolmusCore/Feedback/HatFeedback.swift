import Foundation

/// Kullanıcının bir hat hakkındaki geri bildirimi: iki evet/hayır sorusu ve
/// serbest bir not. Cihazda saklanır; istenirse geliştiriciye gönderilir.
public struct HatFeedback: Sendable, Equatable, Codable {
    /// "Güzergah doğru mu?"; `nil` = cevaplanmadı.
    public var routeIsCorrect: Bool?
    /// "Ücretler güncel mi?"; `nil` = cevaplanmadı.
    public var feesAreCurrent: Bool?
    public var note = ""

    public init(routeIsCorrect: Bool? = nil, feesAreCurrent: Bool? = nil, note: String = "") {
        self.routeIsCorrect = routeIsCorrect
        self.feesAreCurrent = feesAreCurrent
        self.note = note
    }

    public var isEmpty: Bool {
        routeIsCorrect == nil && feesAreCurrent == nil && note.dartTrimmed().isEmpty
    }

    /// Forma gidecek metin; satırlar Android uygulamasınınkiyle aynı, sonda
    /// hangi uygulamadan geldiği.
    public func message(hatID: String, hatName: String, platform: String, date: Date = .now) -> String {
        func answer(_ vote: Bool?) -> String {
            switch vote {
            case true?: "Evet"
            case false?: "Hayır"
            case nil: "—"
            }
        }
        let note = note.dartTrimmed()
        return """
            Hat: \(hatID) — \(hatName)
            Güzergah doğru mu?: \(answer(routeIsCorrect))
            Ücretler güncel mi?: \(answer(feesAreCurrent))
            Not: \(note.isEmpty ? "-" : note)
            Tarih: \(date.formatted(Self.dateStyle))
            Platform: \(platform)
            """
    }

    /// "2026-10-15T14:03:12+03:00" (varsayılan biçim ofseti "+0300" yazar).
    private static let dateStyle = Date.ISO8601FormatStyle(timeZone: .istanbul)
        .year().month().day()
        .time(includingFractionalSeconds: false)
        .timeZone(separator: .colon)
}
