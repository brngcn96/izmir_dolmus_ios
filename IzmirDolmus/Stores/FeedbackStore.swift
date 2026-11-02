import DolmusCore
import Foundation
import Observation

/// Hat geri bildirimlerinin sahibi: oylar ve not cihazda saklanır; istenince
/// geliştiricinin formuna gönderilir.
@Observable
final class FeedbackStore {
    enum Question {
        case route
        case fees
    }

    enum SendState: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    /// Hat kimliği → geri bildirim.
    private(set) var feedbacks: [String: HatFeedback] {
        didSet { defaults.setCodable(feedbacks, forKey: Self.key) }
    }
    /// Hat kimliği → son gönderimin durumu (yalnızca bu oturumda).
    private(set) var sendStates: [String: SendState] = [:]

    private static let key = "hat_feedback_v1"
    private let defaults: UserDefaults
    private let client: APIClient

    init(defaults: UserDefaults = AppEnvironment.defaults, client: APIClient = AppEnvironment.client) {
        self.defaults = defaults
        self.client = client
        self.feedbacks = defaults.codable([String: HatFeedback].self, forKey: Self.key) ?? [:]
    }

    func feedback(for hatID: String) -> HatFeedback {
        feedbacks[hatID] ?? HatFeedback()
    }

    func sendState(for hatID: String) -> SendState {
        sendStates[hatID] ?? .idle
    }

    /// Oy verir; aynı oya yeniden basmak oyu geri alır.
    func vote(_ answer: Bool, on question: Question, for hatID: String) {
        var feedback = feedback(for: hatID)
        switch question {
        case .route: feedback.routeIsCorrect = feedback.routeIsCorrect == answer ? nil : answer
        case .fees: feedback.feesAreCurrent = feedback.feesAreCurrent == answer ? nil : answer
        }
        feedbacks[hatID] = feedback
        sendStates[hatID] = nil
    }

    func setNote(_ note: String, for hatID: String) {
        feedbacks[hatID, default: HatFeedback()].note = note
        sendStates[hatID] = nil
    }

    /// Geri bildirimi forma gönderir. Ekran kapansa da tamamlanır.
    func send(for hat: DolmusHat) async {
        guard sendState(for: hat.id) != .sending else { return }
        sendStates[hat.id] = .sending
        let text = feedback(for: hat.id).message(hatID: hat.id, hatName: hat.name, platform: Self.platform)
        do {
            try await client.send(FeedbackEndpoint(text: text))
            sendStates[hat.id] = .sent
        } catch .cancelled {
            sendStates[hat.id] = .idle
        } catch {
            sendStates[hat.id] = .failed(error.message)
        }
    }

    /// "iOS 27.0 · 1.0"
    private static var platform: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let app = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "iOS \(os.majorVersion).\(os.minorVersion) · \(app)"
    }
}
