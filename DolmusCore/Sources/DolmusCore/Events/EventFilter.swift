import Foundation

/// Etkinliklerin üç kaba türü; liste filtresi ve kart simgesi bunlara göre.
public enum EventCategory: String, CaseIterable, Sendable, Hashable {
    case music
    case stage
    case other

    /// Kaynaktaki türden (Ticketmaster: "Music", "Arts & Theatre"; İBB:
    /// "KONSER", "TİYATRO"…) kovayı bulur.
    public init(rawCategory: String?) {
        let category = trNorm(rawCategory ?? "")
        if ["music", "konser"].contains(where: category.dartContains) {
            self = .music
        } else if ["theat", "sahne", "tiyatro", "stand"].contains(where: category.dartContains) {
            self = .stage
        } else {
            self = .other
        }
    }

    public var title: String {
        switch self {
        case .music: "Konser"
        case .stage: "Sahne"
        case .other: "Diğer"
        }
    }
}

/// Etkinlik listesinin filtreleri; boş küme "hepsi" demektir.
public struct EventFilter: Sendable, Equatable {
    public enum Dates: String, CaseIterable, Sendable {
        case all
        case today
        case week
        case month

        public var title: String {
            switch self {
            case .all: "Tümü"
            case .today: "Bugün"
            case .week: "Bu hafta"
            case .month: "Bu ay"
            }
        }
    }

    public var kinds: Set<EventCategory> = []
    public var venues: Set<String> = []
    public var dates: Dates = .all
    /// Başlıkta aranan metin.
    public var query = ""

    public init() {}

    /// Arama dışında bir filtre seçili mi.
    public var isActive: Bool {
        !kinds.isEmpty || !venues.isEmpty || dates != .all
    }

    /// Filtreleri uygular ve başlangıca göre sıralar; tarihsizler sona.
    ///
    /// Bugünden önce başlamış etkinlikler hiç gösterilmez (Flutter'daki gibi:
    /// süren eski sergiler listenin tepesine düşmesin); bugün başlayanlar kalır.
    /// "Bu hafta" bugün ve sonraki 7 gün, "Bu ay" sonraki 31 gün. Tarihi
    /// olmayan etkinlik tarih filtresinden geçer.
    public func apply(to events: [EventItem], now: Date = .now, calendar: Calendar = .istanbul) -> [EventItem] {
        let today = calendar.startOfDay(for: now)
        let needle = trNorm(query)
        let matching = events.filter { event in
            if let start = event.start, start < today { return false }
            if !kinds.isEmpty, !kinds.contains(event.kind) { return false }
            if !venues.isEmpty, !venues.contains(event.venue ?? "") { return false }
            if dates != .all, let start = event.start {
                let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: start)).day ?? 0
                switch dates {
                case .all: break
                case .today: if days != 0 { return false }
                case .week: if days > 7 { return false }
                case .month: if days > 31 { return false }
                }
            }
            if !needle.isEmpty, !trNorm(event.title).dartContains(needle) { return false }
            return true
        }
        // Sıralama kararlı: aynı saatteki etkinlikler listedeki sırasını korur.
        return matching.sorted { lhs, rhs in
            switch (lhs.start, rhs.start) {
            case let (l?, r?): l < r
            case (.some, nil): true
            case (nil, _): false
            }
        }
    }

    /// Mekan seçenekleri: en çok etkinliği olan önce, eşitlikte ada göre.
    public static func venues(in events: [EventItem]) -> [String] {
        var counts: [String: Int] = [:]
        for venue in events.compactMap(\.venue) {
            counts[venue, default: 0] += 1
        }
        return counts.keys.sorted { lhs, rhs in
            counts[lhs]! != counts[rhs]! ? counts[lhs]! > counts[rhs]! : lhs.dartPrecedes(rhs)
        }
    }
}
