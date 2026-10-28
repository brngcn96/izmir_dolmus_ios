import Foundation

/// Konumun adı: en yakın bilinen yer (Flutter'daki
/// `LocationService.currentWithNearest`).
extension DolmusData {
    /// Konuma en yakın yer (`duraklar`) ve uzaklığı (m). Eşit uzaklıkta
    /// listede önce geleni.
    public func nearestPlace(to point: Coordinate) -> (place: PlacePoint, meters: Double)? {
        var best: (place: PlacePoint, meters: Double)?
        for place in duraklar {
            let meters = point.meters(to: place.coordinate)
            if best.map({ meters < $0.meters }) ?? true {
                best = (place, meters)
            }
        }
        return best
    }
}

/// İzmir'in ilçeleri (Flutter Anasayfa'sındaki `_izmirDistricts`, `_districtOf`).
public enum IzmirDistrict {
    /// Otuz ilçe, `trNorm` ile.
    static let names: Set<String> = [
        "aliaga", "balcova", "bayindir", "bayrakli", "bergama", "beydag",
        "bornova", "buca", "cesme", "cigli", "dikili", "foca", "gaziemir",
        "guzelbahce", "karabaglar", "karaburun", "karsiyaka", "kemalpasa",
        "kinik", "kiraz", "konak", "menderes", "menemen", "narlidere", "odemis",
        "seferihisar", "selcuk", "tire", "torbali", "urla",
    ]

    static let fallback = "İzmir"

    /// "Ad · İlçe" etiketinden yalnızca geçerli bir ilçe adı; çıkmazsa "İzmir"
    /// (durak ya da sokak adı hiç gösterilmez).
    public static func name(fromLabel label: String?) -> String {
        guard let label, let separator = label.lastIndex(of: "·") else { return fallback }
        let token = label[label.index(after: separator)...].trimmingCharacters(in: .whitespaces)
        return names.contains(trNorm(token)) ? token : fallback
    }

    /// Etiket İzmir'deki bir ilçeye çıkıyor mu.
    public static func isDistrict(_ name: String) -> Bool {
        names.contains(trNorm(name))
    }
}
