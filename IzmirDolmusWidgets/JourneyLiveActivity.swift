//
//  JourneyLiveActivity.swift
//  IzmirDolmus
//
//  Created by Baran Göcen on 29.10.2026.
//

import ActivityKit
import SwiftUI
import WidgetKit

/// Yolculuk modunun görünümleri: kilit ekranı (ve bildirim merkezi) ile
/// Dynamic Island'ın üç hali. Veriyi uygulama gönderir; burada yalnızca çizilir.
struct JourneyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: JourneyActivityAttributes.self) { context in
            JourneyLockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            let attributes = context.attributes
            let state = context.state
            return DynamicIsland {
                // Genişletilmiş: Dynamic Island'a basılı tutunca.
                DynamicIslandExpandedRegion(.leading) {
                    StepIcon(kind: attributes.step(for: state)?.kind, hasArrived: state.hasArrived)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(attributes.distanceText(for: state))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(attributes.headline(for: state))
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(attributes.detail(for: state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        StepProgress(count: attributes.steps.count, current: state.stepIndex, hasArrived: state.hasArrived)
                    }
                }
            } compactLeading: {
                StepIcon(kind: attributes.step(for: state)?.kind, hasArrived: state.hasArrived)
            } compactTrailing: {
                Text(attributes.distanceText(for: state))
                    .monospacedDigit()
            } minimal: {
                StepIcon(kind: attributes.step(for: state)?.kind, hasArrived: state.hasArrived)
            }
            .keylineTint(.accentColor)
        }
    }
}

/// Kilit ekranı ve bildirim merkezi görünümü.
struct JourneyLockScreenView: View {
    let attributes: JourneyActivityAttributes
    let state: JourneyActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                StepIcon(kind: attributes.step(for: state)?.kind, hasArrived: state.hasArrived)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.headline(for: state))
                        .font(.headline)
                        .lineLimit(1)
                    Text(attributes.detail(for: state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(attributes.distanceText(for: state))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }
            StepProgress(count: attributes.steps.count, current: state.stepIndex, hasArrived: state.hasArrived)
        }
        .padding(16)
    }
}

/// Adımın simgesi: yürüme, dolmuş ya da varış.
private struct StepIcon: View {
    let kind: JourneyActivityAttributes.Step.Kind?
    let hasArrived: Bool

    var body: some View {
        Image(systemName: hasArrived ? "checkmark.circle.fill" : kind == .ride ? "bus.fill" : "figure.walk")
            .foregroundStyle(.tint)
    }
}

/// Adımların ilerleme çubuğu: geçilenler dolu, şu anki vurgulu.
private struct StepProgress: View {
    let count: Int
    let current: Int
    let hasArrived: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(hasArrived || index < current ? AnyShapeStyle(.tint) : index == current ? AnyShapeStyle(.tint.opacity(0.6)) : AnyShapeStyle(.secondary.opacity(0.3)))
                    .frame(height: 4)
            }
        }
    }
}

extension JourneyActivityAttributes {
    func step(for state: ContentState) -> Step? {
        steps.indices.contains(state.stepIndex) ? steps[state.stepIndex] : nil
    }

    /// Şu anki adım tek cümleyle.
    func headline(for state: ContentState) -> String {
        if state.hasArrived { return "Vardın" }
        guard let step = step(for: state) else { return toLabel }
        switch step.kind {
        case .ride:
            return state.isApproaching ? "Hazırlan, inişe az kaldı" : "\(step.title) dolmuşu"
        case .walk:
            return state.stepIndex == steps.count - 1 ? "Varışa yürü" : "Durağa yürü"
        }
    }

    /// Ayrıntı: nereye, ne kadar sürecek.
    func detail(for state: ContentState) -> String {
        if state.hasArrived { return toLabel }
        guard let step = step(for: state) else { return "\(fromLabel) → \(toLabel)" }
        switch step.kind {
        case .ride: return "Adım \(state.stepIndex + 1)/\(steps.count) · \(fromLabel) → \(toLabel)"
        case .walk: return state.stepIndex == steps.count - 1 ? step.title : "\(step.title) için"
        }
    }

    /// "350 m", "2,3 km"; mesafe bilinmiyorsa adım sayısı.
    func distanceText(for state: ContentState) -> String {
        if state.hasArrived { return "✓" }
        guard let meters = state.metersRemaining else { return "\(state.stepIndex + 1)/\(steps.count)" }
        if meters < 1000 { return "\(meters) m" }
        let kilometers = Double(meters) / 1000
        return "\(kilometers.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "tr_TR")))) km"
    }
}

// MARK: - Önizleme

extension JourneyActivityAttributes {
    fileprivate static let preview = JourneyActivityAttributes(
        fromLabel: "Bornova Metro",
        toLabel: "Şirinyer",
        totalMinutes: 42,
        steps: [
            Step(kind: .walk, title: "Buca - Bornova", meters: 90),
            Step(kind: .ride, title: "Buca - Bornova", meters: 9_400),
            Step(kind: .walk, title: "Şirinyer", meters: 334),
        ]
    )
}

#Preview("Kilit ekranı", as: .content, using: JourneyActivityAttributes.preview) {
    JourneyLiveActivity()
} contentStates: {
    JourneyActivityAttributes.ContentState(stepIndex: 0, metersRemaining: 90)
    JourneyActivityAttributes.ContentState(stepIndex: 1, metersRemaining: 2_300)
    JourneyActivityAttributes.ContentState(stepIndex: 1, metersRemaining: 350, isApproaching: true)
    JourneyActivityAttributes.ContentState(stepIndex: 2, hasArrived: true)
}
