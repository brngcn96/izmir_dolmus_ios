/// Bir ana hat: dolmuşun üzerinde yazan ad. Altındaki `segments`, o hatta sık
/// gidilen güzergahların ücret satırlarıdır.
public struct DolmusHat: Sendable, Equatable, Identifiable {
    /// `group_id`; bölünmüş hatlarda türetilmiş kimlik (ör. `M41#buca`).
    public let id: String
    public let name: String
    public let segments: [DolmusRoute]
    /// İBB ücret servisindeki gerçek hat kodu. Normalde `id` ile aynıdır;
    /// bölünmüş hatlar ana hattın kodunu taşır ki ücreti aynı koddan çeksinler.
    public let apiCode: String
    /// Ücret satırı olmayan (yalnızca geometri taşıyan) bölme hatlarında ilçe
    /// satırlardan okunamaz; ana hattan miras alınıp burada tutulur.
    let inheritedIlce: String?

    public init(
        id: String,
        name: String,
        segments: [DolmusRoute],
        apiCode: String? = nil,
        ilce: String? = nil
    ) {
        self.id = id
        self.name = name
        self.segments = segments
        self.apiCode = apiCode ?? id
        self.inheritedIlce = ilce
    }

    /// Hattın geçtiği ilçe(ler): önce satırlardan (resmi veri), satır yoksa
    /// ana hattan miras alınan değer.
    public var ilce: String? {
        segments.isEmpty ? inheritedIlce : segments[0].ilce
    }

    public var feeMin: Int? { segments.compactMap(\.fee).min() }
    public var feeMax: Int? { segments.compactMap(\.fee).max() }

    /// "55 ₺", "55–90 ₺" ya da ücret bilinmiyorsa "Ücret ?".
    public var feeLabel: String {
        guard let feeMin, let feeMax else { return "Ücret ?" }
        return feeMin == feeMax ? "\(feeMin) ₺" : "\(feeMin)–\(feeMax) ₺"
    }

    /// Hat detayında herkese gösterilen editoryal not (kullanıcının kişisel
    /// notundan ayrı); yoksa `nil`.
    public var info: String? { HatOverrides.info(for: id) }

    /// Hattaki kilit noktaların tekrarsız listesi, satırlardaki görünüş sırasıyla.
    public var keyStopNames: [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for segment in segments {
            for (stop, norm) in zip(segment.stops, segment.stopsNorm) {
                if seen.insert(norm).inserted {
                    result.append(stop)
                }
            }
        }
        return result
    }
}
