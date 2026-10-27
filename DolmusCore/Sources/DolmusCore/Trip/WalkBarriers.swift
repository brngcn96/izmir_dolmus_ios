/// Yürüme engelleri: yayaya kapalı (çitli) alanlar. Kuş uçuşu yürüme modeli
/// engelleri bilmez; bir bacağın tam bir ucu alanın içindeyse (çiti geçiyorsa)
/// o bacak, dolayısıyla o rota geçersizdir.
public enum WalkBarriers {
    struct Barrier {
        let center: Coordinate
        let radius: Double
        let note: String
    }

    static let barriers = [
        // Adnan Menderes Havalimanı: dolmuşlar çitli otoyoldan geçer; terminale yürünmez.
        Barrier(
            center: Coordinate(latitude: 38.2913, longitude: 27.14787),
            radius: 300,
            note: "Havalimanına dolmuşla doğrudan erişim yok — İZBAN (Adnan Menderes istasyonu) ya da Havaş kullanın."
        ),
    ]

    static func isInside(_ point: Coordinate, _ barrier: Barrier) -> Bool {
        point.meters(to: barrier.center) <= barrier.radius
    }

    /// Bu yürüme bacağı bir engelin sınırını geçiyor mu (bir ucu içeride, öteki dışarıda)?
    public static func crosses(_ a: Coordinate, _ b: Coordinate) -> Bool {
        barriers.contains { isInside(a, $0) != isInside(b, $0) }
    }

    /// Nokta bir engelin içindeyse kullanıcıya gösterilecek not.
    public static func note(for point: Coordinate) -> String? {
        barriers.first { isInside(point, $0) }?.note
    }
}
