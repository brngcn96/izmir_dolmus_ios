import Foundation

/// Kartın ve uygulamadaki bandın metinleri: kilit ekranı, Dynamic Island ve
/// uygulama aynı cümleleri kullanır.
extension JourneyActivityAttributes {
    /// Güncelleme bir süredir gelmediğinde ayrıntı satırı.
    nonisolated static let staleText = "Konum güncellenmiyor"

    nonisolated func step(for state: ContentState) -> Step? {
        steps.indices.contains(state.stepIndex) ? steps[state.stepIndex] : nil
    }

    /// Şu anki adım tek cümleyle.
    nonisolated func headline(for state: ContentState) -> String {
        if state.hasArrived { return "Vardın" }
        guard let step = step(for: state) else { return toLabel }
        switch step.kind {
        case .ride:
            if state.isOffRoute { return "Güzergahtan çıktın" }
            return state.isApproaching ? "Hazırlan, inişe az kaldı" : "\(step.title) dolmuşu"
        case .walk:
            return state.stepIndex == steps.count - 1 ? "Varışa yürü" : "Durağa yürü"
        }
    }

    /// Ayrıntı: nereye, kaçıncı adım.
    nonisolated func detail(for state: ContentState) -> String {
        if state.hasArrived { return toLabel }
        guard let step = step(for: state) else { return "\(fromLabel) → \(toLabel)" }
        switch step.kind {
        case .ride: return "Adım \(state.stepIndex + 1)/\(steps.count) · \(fromLabel) → \(toLabel)"
        case .walk: return state.stepIndex == steps.count - 1 ? step.title : "\(step.title) için"
        }
    }

    /// "350 m" (10 m adımlarla), "2,3 km"; mesafe bilinmiyorsa adım sayısı.
    nonisolated func distanceText(for state: ContentState) -> String {
        if state.hasArrived { return "✓" }
        guard let meters = state.metersRemaining else { return "\(state.stepIndex + 1)/\(steps.count)" }
        if meters < 1000 { return "\(Self.roundedMeters(meters)) m" }
        return "\(Self.kilometers(meters)) km"
    }

    /// VoiceOver için: "350 metre", "2,3 kilometre".
    nonisolated func spokenDistance(for state: ContentState) -> String {
        if state.hasArrived { return "varıldı" }
        guard let meters = state.metersRemaining else { return "adım \(state.stepIndex + 1), toplam \(steps.count)" }
        return meters < 1000 ? "\(Self.roundedMeters(meters)) metre" : "\(Self.kilometers(meters)) kilometre"
    }

    /// Ekranda yazılan mesafe değişmediyse kart güncellenmez; ikisi aynı yuvarlamayı kullanır.
    nonisolated static func roundedMeters(_ meters: Int) -> Int {
        (meters + 5) / 10 * 10
    }

    nonisolated static func kilometers(_ meters: Int) -> String {
        (Double(meters) / 1000).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "tr_TR")))
    }
}
