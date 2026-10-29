import Foundation

/// Widget'ların okuduğu küçük özet. Uygulama kurar ve paylaşılan klasöre (App
/// Group) yazar; widget eklentisi yalnızca okur.
///
/// Widget eklentisi bütün veriyi yükleyemez: veri belleğe ~32 MB, planlayıcı
/// ~4 MB ekliyor, eklentinin bellek sınırı ise dar. Özet birkaç on KB.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    /// Biçim değişince artar; widget tanımadığı sürümü okumaz.
    public static let currentVersion = 1
    /// Paylaşılan klasördeki dosyanın adı.
    public static let fileName = "widget-snapshot.json"

    public var version: Int
    public var createdAt: Date
    /// Ev → İş tarifi; adreslerden biri yoksa ya da rota bulunamadıysa `nil`.
    public var toWork: Commute?
    /// İş → Ev tarifi.
    public var toHome: Commute?
    /// Ev ve İş ayarlı mı (tarif yoksa widget'ın ne diyeceği buna bağlı).
    public var hasHome: Bool
    public var hasWork: Bool
    /// Favori hatlar, favori sırasıyla.
    public var favorites: [Hat]
    /// Bütün hatlar: yapılandırılabilir widget'ta hat seçmek için.
    public var catalog: [Hat]

    public init(
        createdAt: Date,
        toWork: Commute?,
        toHome: Commute?,
        hasHome: Bool,
        hasWork: Bool,
        favorites: [Hat],
        catalog: [Hat]
    ) {
        version = Self.currentVersion
        self.createdAt = createdAt
        self.toWork = toWork
        self.toHome = toHome
        self.hasHome = hasHome
        self.hasWork = hasWork
        self.favorites = favorites
        self.catalog = catalog
    }

    /// Yöne göre tarif.
    public func commute(_ direction: CommuteDirection) -> Commute? {
        direction == .toWork ? toWork : toHome
    }
}

extension WidgetSnapshot {
    /// İki adres arasındaki tarif: önerilen ve (varsa) ikinci seçenek.
    public struct Commute: Codable, Sendable, Equatable {
        public var fromLabel: String
        public var toLabel: String
        /// İyiden kötüye; ilki "önerilen". Boş olmaz.
        public var options: [Option]

        public init(fromLabel: String, toLabel: String, options: [Option]) {
            self.fromLabel = fromLabel
            self.toLabel = toLabel
            self.options = options
        }

        public var recommended: Option {
            options[0]
        }
    }

    /// Bir tarif seçeneğinin widget'ta gösterilen kısmı.
    public struct Option: Codable, Sendable, Equatable {
        public var minutes: Int
        public var transfers: Int
        /// "40–60 ₺" ya da "Ücret ?".
        public var feeLabel: String
        /// Ücretin rengi için (en düşük ücret).
        public var feeMin: Int?
        public var steps: [Step]

        public init(minutes: Int, transfers: Int, feeLabel: String, feeMin: Int?, steps: [Step]) {
            self.minutes = minutes
            self.transfers = transfers
            self.feeLabel = feeLabel
            self.feeMin = feeMin
            self.steps = steps
        }

        public init(_ journey: Journey) {
            minutes = journey.estimatedMinutes
            transfers = journey.transfers
            feeLabel = journey.feeLabel
            feeMin = journey.feeMin
            steps = journey.legs.map { leg in
                switch leg {
                case .walk(let walk): .walk(meters: Int(walk.meters.rounded()))
                case .ride(let ride): .ride(hatID: ride.hatID, hatName: ride.hatName)
                }
            }
        }
    }

    /// Tarifin bir adımı: yürüme ya da dolmuş.
    public enum Step: Codable, Sendable, Equatable {
        case walk(meters: Int)
        case ride(hatID: String, hatName: String)
    }

    /// Bir hattın widget'ta gösterilen kısmı.
    public struct Hat: Codable, Sendable, Equatable, Identifiable {
        public var id: String
        public var name: String
        public var feeLabel: String
        public var feeMin: Int?

        public init(id: String, name: String, feeLabel: String, feeMin: Int?) {
            self.id = id
            self.name = name
            self.feeLabel = feeLabel
            self.feeMin = feeMin
        }

        public init(_ hat: DolmusHat) {
            id = hat.id
            name = hat.name
            feeLabel = hat.feeLabel
            feeMin = hat.feeMin
        }
    }
}

extension WidgetSnapshot {
    /// Özeti kurar. Tarifleri planlayıcı hesaplar (yüzlerce ms sürebilir): ana
    /// aktörün dışında çağrılmalı.
    public static func make(
        data: DolmusData,
        planner: JourneyPlanner,
        home: PlacePoint?,
        work: PlacePoint?,
        favoriteHatIDs: [String],
        now: Date = .now
    ) -> WidgetSnapshot {
        func commute(from: PlacePoint?, to: PlacePoint?) -> Commute? {
            guard let from, let to, from.coordinate != to.coordinate else { return nil }
            // Uygulamadaki yol tarifiyle aynı sonuç: aynı sınır (5) ile planla,
            // ilk ikisini al.
            let journeys = planner.planTrip(from: from.coordinate, to: to.coordinate, fees: { id in
                let hat = data.hat(id: id)
                return (hat?.feeMin, hat?.feeMax)
            })
            guard !journeys.isEmpty else { return nil }
            return Commute(fromLabel: from.label, toLabel: to.label, options: journeys.prefix(2).map(Option.init))
        }

        return WidgetSnapshot(
            createdAt: now,
            toWork: commute(from: home, to: work),
            toHome: commute(from: work, to: home),
            hasHome: home != nil,
            hasWork: work != nil,
            favorites: favoriteHatIDs.compactMap { data.hat(id: $0) }.map(Hat.init),
            catalog: data.hats.map(Hat.init)
        )
    }
}
