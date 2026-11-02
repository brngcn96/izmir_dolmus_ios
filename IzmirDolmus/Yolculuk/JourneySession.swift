//
//  JourneySession.swift
//  IzmirDolmus
//
//  Created by Baran Göcen on 29.10.2026.
//

import ActivityKit
import CoreLocation
import DolmusCore
import Foundation
import Observation
import UserNotifications

/// Süren yolculuğun kaydı: uygulama kapanıp açılınca (ya da sistem onu arka planda
/// yeniden başlatınca) takip kaldığı yerden sürer.
struct SavedJourney: Codable, Equatable {
    var journey: Journey
    var from: PlacePoint
    var to: PlacePoint
    /// Live Activity'nin kimliği; Canlı Etkinlikler kapalıysa `nil`.
    var activityID: String?
    var legIndex = 0
}

/// Yolculuk modu: seçilen tarifi konumla adım adım izler (`JourneyTracker`), Live
/// Activity ile kilit ekranında ve Dynamic Island'da gösterir, inişe yaklaşınca
/// uyarır. Konum arka planda da gelir (`CLBackgroundActivitySession`); yolculuk
/// bitince ya da iptal edilince kapanır.
@Observable
final class JourneySession {
    typealias State = JourneyActivityAttributes.ContentState

    /// Süren yolculuğun sabit kısmı; yolculuk yoksa `nil`.
    private(set) var attributes: JourneyActivityAttributes?
    private(set) var state: State?
    /// Süren yolculuk; yoksa `nil`.
    private(set) var current: SavedJourney?
    var errorMessage: String?

    var isActive: Bool {
        current != nil
    }

    private var tracker: JourneyTracker?
    private var locationTask: Task<Void, Never>?
    private var activityStateTask: Task<Void, Never>?
    private var backgroundActivity: CLBackgroundActivitySession?
    private var serviceSession: CLServiceSession?
    /// Karta en son gönderilen durum ve zamanı: ekranda değişmeyecek güncelleme gönderilmez.
    private var sent: (state: State, date: Date)?

    private let defaults: UserDefaults
    private static let key = "journey_v1"
    /// Bu süre güncelleme gelmezse kart "bayat" sayılır (konum kesildi, uygulama durdu).
    static let staleAfter: TimeInterval = 5 * 60
    /// Ekranda değişiklik olmasa da bu aralıkla güncellenir: kart bayatlamasın.
    static let heartbeat: TimeInterval = 3 * 60

    init(defaults: UserDefaults = AppEnvironment.defaults) {
        self.defaults = defaults
        // Live Activity düğmeleri (`LiveActivityIntent`) uygulamanın sürecinde çalışır ve buraya gelir.
        JourneyActions.shared.advance = { [weak self] in self?.advance() }
        JourneyActions.shared.end = { [weak self] in self?.end() }
        restore()
    }

    // MARK: Başlat, ilerlet, bitir

    /// Yolculuğu başlatır. ActivityKit kuralı: Live Activity uygulama öndeyken başlar;
    /// arka planda konum oturumu da yalnızca öndeyken başlayabilir.
    func start(journey: Journey, from: PlacePoint, to: PlacePoint) {
        finish(arrived: false)
        let attributes = JourneyActivityAttributes(journey: journey, from: from, to: to)
        let tracker = JourneyTracker(journey: journey)
        let state = State(progress: tracker.progress)
        var activityID: String?
        errorMessage = nil
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                activityID = try Activity.request(attributes: attributes, content: Self.content(state)).id
            } catch {
                errorMessage = "Canlı Etkinlik başlatılamadı; uyarılar bildirim olarak gelecek."
            }
        } else {
            errorMessage = "Canlı Etkinlikler kapalı (Ayarlar › İzmir Dolmuş); uyarılar bildirim olarak gelecek."
        }
        if activityID == nil {
            Task { await JourneyNotifier.requestAuthorization() }
        }
        // Önceki oturumdan kalan ya da beş dakika duran "Vardın" kartı yeninin üstüne binmesin.
        Task { await Self.endActivities(except: activityID) }
        self.attributes = attributes
        self.state = state
        self.tracker = tracker
        sent = (state, .now)
        current = SavedJourney(journey: journey, from: from, to: to, activityID: activityID)
        save()
        startTracking()
    }

    /// Konum yetmediğinde elle ilerletme ("Sonraki adım").
    func advance() {
        guard var tracker else { return }
        let events = tracker.advanceManually()
        self.tracker = tracker
        apply(events, progress: tracker.progress)
    }

    /// Kullanıcı yolculuğu bitirdi: kart hemen kalkar, konum kapanır.
    func end() {
        finish(arrived: false)
    }

    // MARK: Konum

    /// Konumu dinlemeye başlar. Arka plan oturumu (`CLBackgroundActivitySession`)
    /// açık kaldıkça "kullanırken" izniyle arka planda da konum gelir; sistem durum
    /// çubuğunda bunu gösterir.
    private func startTracking() {
        serviceSession = CLServiceSession(authorization: .whenInUse)
        backgroundActivity = CLBackgroundActivitySession()
        locationTask = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.otherNavigation) {
                    guard let self, !Task.isCancelled else { return }
                    if let location = update.location {
                        self.handle(LocationFix(location))
                    }
                }
            } catch {
                // Akış kesilirse (ör. izin kalktı) takip elle sürer.
            }
        }
        observeActivity()
    }

    /// Kullanıcı kartı kilit ekranından kaldırırsa yolculuk da biter.
    private func observeActivity() {
        guard let id = current?.activityID, let activity = Self.activity(id) else { return }
        activityStateTask = Task { [weak self] in
            for await activityState in activity.activityStateUpdates {
                if activityState == .dismissed || activityState == .ended {
                    self?.finish(arrived: false, endActivity: false)
                    return
                }
            }
        }
    }

    private func handle(_ fix: LocationFix) {
        guard var tracker else { return }
        let events = tracker.update(with: fix)
        self.tracker = tracker
        apply(events, progress: tracker.progress)
    }

    /// Takipten gelenleri ekrana, karta ve uyarılara çevirir.
    private func apply(_ events: [JourneyEvent], progress: JourneyProgress) {
        guard let attributes, var current else { return }
        let state = State(progress: progress)
        self.state = state
        if current.legIndex != progress.legIndex {
            current.legIndex = progress.legIndex
            self.current = current
            save()
        }
        let alert = JourneyAlert(for: events, attributes: attributes)
        if progress.hasArrived {
            finish(arrived: true, finalState: state, alert: alert)
            return
        }
        guard alert != nil || Self.needsUpdate(from: sent, to: state) else { return }
        sent = (state, .now)
        if let id = current.activityID {
            Task { await Self.update(id, Self.content(state), alert: alert?.configuration) }
        } else if let alert {
            JourneyNotifier.post(alert)
        }
    }

    /// Yolculuğu kapatır: konum durur; kart varıldıysa beş dakika kalır, değilse hemen kalkar.
    private func finish(arrived: Bool, finalState: State? = nil, alert: JourneyAlert? = nil, endActivity: Bool = true) {
        guard let current else { return }
        locationTask?.cancel()
        locationTask = nil
        activityStateTask?.cancel()
        activityStateTask = nil
        backgroundActivity?.invalidate()
        backgroundActivity = nil
        serviceSession?.invalidate()
        serviceSession = nil
        let final = finalState ?? state ?? State(stepIndex: 0)
        self.current = nil
        attributes = nil
        state = nil
        tracker = nil
        sent = nil
        save()
        if let id = current.activityID {
            guard endActivity else { return }
            let dismissal: ActivityUIDismissalPolicy = arrived ? .after(.now.addingTimeInterval(5 * 60)) : .immediate
            Task { await Self.end(id, Self.content(final), dismissal: dismissal, alert: alert?.configuration) }
        } else if let alert {
            JourneyNotifier.post(alert)
        }
    }

    /// Kartta görünen bir şey değişti mi, ya da kart bayatlamak üzere mi?
    static func needsUpdate(from sent: (state: State, date: Date)?, to state: State, now: Date = .now) -> Bool {
        guard let sent else { return true }
        let old = sent.state
        func shown(_ meters: Int?) -> Int? {
            meters.map { $0 < 1000 ? JourneyActivityAttributes.roundedMeters($0) : 1000 + $0 / 100 }
        }
        return old.stepIndex != state.stepIndex || old.isApproaching != state.isApproaching
            || old.isOffRoute != state.isOffRoute || old.hasArrived != state.hasArrived
            || shown(old.metersRemaining) != shown(state.metersRemaining)
            || now.timeIntervalSince(sent.date) >= heartbeat
    }

    // MARK: Kayıt ve sürdürme

    private func save() {
        defaults.setCodable(current, forKey: Self.key)
    }

    /// Açılışta: kayıtlı yolculuk sürüyorsa kaldığı yerden devam eder. Kaydı olmayan
    /// kartları (önceki bir oturumdan kalan) kapatır.
    private func restore() {
        guard let saved = defaults.codable(SavedJourney.self, forKey: Self.key) else {
            Task { await Self.endActivities(except: nil) }
            return
        }
        if let id = saved.activityID {
            guard let activity = Self.activity(id), activity.activityState == .active || activity.activityState == .stale else {
                // Kart kaldırılmış ya da süresi dolmuş: yolculuk da biter.
                defaults.removeObject(forKey: Self.key)
                Task { await Self.endActivities(except: nil) }
                return
            }
            attributes = activity.attributes
            state = activity.content.state
        } else {
            attributes = JourneyActivityAttributes(journey: saved.journey, from: saved.from, to: saved.to)
        }
        let tracker = JourneyTracker(journey: saved.journey, legIndex: saved.legIndex)
        if state == nil {
            state = State(progress: tracker.progress)
        }
        self.tracker = tracker
        sent = state.map { ($0, .now) }
        current = saved
        Task { await Self.endActivities(except: saved.activityID) }
        // Sistem uygulamayı arka planda yeniden açtıysa oturum hemen yeniden kurulmalı.
        startTracking()
    }

    // MARK: ActivityKit

    // ActivityKit'in güncelleme ve bitirme metotları ana aktörde çalışmaz. Ana
    // aktörden yalnızca Sendable olan kimlik ve içerik geçer; etkinlik orada,
    // sistemin listesinden kimliğiyle bulunur.

    static func content(_ state: State) -> ActivityContent<State> {
        ActivityContent(state: state, staleDate: .now.addingTimeInterval(staleAfter))
    }

    @concurrent
    private static func update(_ id: String, _ content: ActivityContent<State>, alert: AlertConfiguration?) async {
        await activity(id)?.update(content, alertConfiguration: alert)
    }

    @concurrent
    private static func end(_ id: String, _ content: ActivityContent<State>, dismissal: ActivityUIDismissalPolicy, alert: AlertConfiguration?) async {
        guard let activity = activity(id) else { return }
        if let alert {
            await activity.update(content, alertConfiguration: alert)
        }
        await activity.end(content, dismissalPolicy: dismissal)
    }

    /// Bu uygulamanın `id` dışındaki bütün yolculuk kartlarını hemen kapatır.
    @concurrent
    private static func endActivities(except id: String?) async {
        for activity in Activity<JourneyActivityAttributes>.activities where activity.id != id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    nonisolated private static func activity(_ id: String) -> Activity<JourneyActivityAttributes>? {
        Activity<JourneyActivityAttributes>.activities.first { $0.id == id }
    }
}

/// Uyarı: Live Activity açıksa kartla (`AlertConfiguration`), kapalıysa yerel bildirimle.
struct JourneyAlert: Equatable {
    var title: String
    var body: String

    /// Bir ölçümün olaylarından en önemlisinin uyarısı; uyarı gerektirmiyorsa `nil`.
    init?(for events: [JourneyEvent], attributes: JourneyActivityAttributes) {
        func hat(_ index: Int) -> String {
            attributes.steps.indices.contains(index) ? attributes.steps[index].title : "Dolmuş"
        }
        let ranked = events.compactMap { event -> (rank: Int, title: String, body: String)? in
            switch event {
            case .arrived:
                (5, "Vardın", attributes.toLabel)
            case .getOff(let leg):
                (4, "İnme zamanı", "\(hat(leg)): iniş noktasındasın, şoföre \"inecek var\" de.")
            case .approaching(let leg):
                (3, "Hazırlan, inişe az kaldı", "\(hat(leg)): yaklaşık 400 m sonra ineceksin.")
            case .offRoute(let leg):
                (2, "Güzergahtan çıktın", "\(hat(leg)) güzergahından uzaklaştın; doğru dolmuşta mısın?")
            case .advanced(let leg):
                attributes.steps.indices.contains(leg) && attributes.steps[leg].kind == .ride
                    ? (1, "Durağa geldin", "\(hat(leg)) dolmuşuna bin.") : nil
            case .backOnRoute:
                nil
            }
        }
        guard let top = ranked.max(by: { $0.rank < $1.rank }) else { return nil }
        title = top.title
        body = top.body
    }

    var configuration: AlertConfiguration {
        AlertConfiguration(title: "\(title)", body: "\(body)", sound: .default)
    }
}

/// Canlı Etkinlikler kapalıyken uyarılar yerel bildirimle gelir.
enum JourneyNotifier {
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func post(_ alert: JourneyAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
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

extension JourneyActivityAttributes.ContentState {
    init(progress: JourneyProgress) {
        self.init(
            stepIndex: progress.legIndex,
            metersRemaining: progress.metersRemaining,
            isApproaching: progress.isApproaching,
            hasArrived: progress.hasArrived,
            isOffRoute: progress.isOffRoute
        )
    }
}

extension LocationFix {
    init(_ location: CLLocation) {
        self.init(
            coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            accuracy: location.horizontalAccuracy
        )
    }
}
