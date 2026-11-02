//
//  JourneySession.swift
//  IzmirDolmus
//
//  Created by Baran Göcen on 29.10.2026.
//

import ActivityKit
import DolmusCore
import Foundation
import Observation

/// Yolculuk modu: seçilen tarifi Live Activity ile kilit ekranında ve Dynamic
/// Island'da gösterir. Bu adımda adımlar elle ilerliyor; konumla takip sonra.
@Observable
final class JourneySession {
    typealias State = JourneyActivityAttributes.ContentState

    /// Süren yolculuğun sabit kısmı; yolculuk yoksa `nil`.
    private(set) var attributes: JourneyActivityAttributes?
    private(set) var state: State?
    var errorMessage: String?
    /// `Activity` Sendable değil: ana aktörden başka yere gönderilemez. Etkinliği
    /// kimliğiyle tutup gerektiğinde yeniden buluyoruz (aşağıda).
    private var activityID: String?

    var isActive: Bool {
        activityID != nil
    }

    /// Live Activity'yi başlatır. ActivityKit kuralı: uygulama öndeyken.
    func start(journey: Journey, from: PlacePoint, to: PlacePoint) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            errorMessage = "Canlı Etkinlikler kapalı: Ayarlar › İzmir Dolmuş."
            return
        }
        let attributes = JourneyActivityAttributes(journey: journey, from: from, to: to)
        let state = State(stepIndex: 0, metersRemaining: attributes.steps.first?.meters)
        do {
            let activity = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
            activityID = activity.id
            self.attributes = attributes
            self.state = state
            errorMessage = nil
        } catch {
            errorMessage = "Yolculuk başlatılamadı: \(error.localizedDescription)"
        }
    }

    /// Sıradaki adıma geçer; son adımdan sonra varış.
    func advance() async {
        guard let activityID, let attributes, var state else { return }
        if state.stepIndex + 1 < attributes.steps.count {
            state.stepIndex += 1
            state.metersRemaining = attributes.steps[state.stepIndex].meters
        } else {
            state.hasArrived = true
            state.metersRemaining = nil
        }
        self.state = state
        await Self.update(activityID, ActivityContent(state: state, staleDate: nil))
    }

    /// Etkinliği bitirir. Varıldıysa son hali beş dakika kilit ekranında kalır.
    func end() async {
        guard let activityID else { return }
        let final = state ?? State(stepIndex: 0)
        let dismissal: ActivityUIDismissalPolicy = final.hasArrived ? .after(.now.addingTimeInterval(5 * 60)) : .immediate
        self.activityID = nil
        attributes = nil
        state = nil
        await Self.end(activityID, ActivityContent(state: final, staleDate: nil), dismissal: dismissal)
    }

    // ActivityKit'in güncelleme ve bitirme metotları ana aktörde çalışmaz. Ana
    // aktörden yalnızca Sendable olan kimlik ve içerik geçer; etkinlik orada,
    // sistemin listesinden kimliğiyle bulunur.

    @concurrent
    private static func update(_ id: String, _ content: ActivityContent<State>) async {
        await activity(id)?.update(content)
    }

    @concurrent
    private static func end(_ id: String, _ content: ActivityContent<State>, dismissal: ActivityUIDismissalPolicy) async {
        await activity(id)?.end(content, dismissalPolicy: dismissal)
    }

    nonisolated private static func activity(_ id: String) -> Activity<JourneyActivityAttributes>? {
        Activity<JourneyActivityAttributes>.activities.first { $0.id == id }
    }
}

extension JourneyActivityAttributes {
    /// Tarifin bacaklarından Live Activity'nin sabit kısmı.
    init(journey: Journey, from: PlacePoint, to: PlacePoint) {
        let lastIndex = journey.legs.count - 1
        self.init(
            fromLabel: from.label,
            toLabel: to.label,
            totalMinutes: journey.estimatedMinutes,
            steps: journey.legs.enumerated().map { index, leg in
                switch leg {
                case .walk(let walk):
                    // Son yürüme varışa, öncekiler binilecek hattın durağına.
                    Step(kind: .walk, title: index == lastIndex ? to.label : walk.toLabel, meters: Int(walk.meters.rounded()))
                case .ride(let ride):
                    Step(kind: .ride, title: ride.hatName, meters: Int(ride.meters.rounded()))
                }
            }
        )
    }
}
