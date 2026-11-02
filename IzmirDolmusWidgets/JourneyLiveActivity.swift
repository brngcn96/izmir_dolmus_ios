//
//  JourneyLiveActivity.swift
//  IzmirDolmus
//
//  Created by Baran Göcen on 29.10.2026.
//

import ActivityKit
import AppIntents
import DolmusCore
import SwiftUI
import WidgetKit

/// Yolculuk modunun görünümleri: kilit ekranı (ve bildirim merkezi) ile
/// Dynamic Island'ın üç hali. Veriyi uygulama gönderir; burada yalnızca çizilir.
struct JourneyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: JourneyActivityAttributes.self) { context in
            JourneyLockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
                // Dokununca uygulama süren yolculuğun tarifini haritada açar.
                .widgetURL(DeepLink.journey.url)
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
                        .accessibilityLabel(attributes.spokenDistance(for: state))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(attributes.headline(for: state))
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.isStale ? JourneyActivityAttributes.staleText : attributes.detail(for: state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        StepProgress(count: attributes.steps.count, current: state.stepIndex, hasArrived: state.hasArrived)
                        if !state.hasArrived {
                            JourneyButtons()
                        }
                    }
                }
            } compactLeading: {
                StepIcon(kind: attributes.step(for: state)?.kind, hasArrived: state.hasArrived)
            } compactTrailing: {
                Text(attributes.distanceText(for: state))
                    .monospacedDigit()
                    .accessibilityLabel(attributes.spokenDistance(for: state))
            } minimal: {
                StepIcon(kind: attributes.step(for: state)?.kind, hasArrived: state.hasArrived)
            }
            .keylineTint(.accentColor)
            .widgetURL(DeepLink.journey.url)
        }
    }
}

/// Kilit ekranı ve bildirim merkezi görünümü.
struct JourneyLockScreenView: View {
    let attributes: JourneyActivityAttributes
    let state: JourneyActivityAttributes.ContentState
    /// Bir süredir güncelleme gelmedi (konum kesildi ya da uygulama durdu).
    var isStale = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                StepIcon(kind: attributes.step(for: state)?.kind, hasArrived: state.hasArrived)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.headline(for: state))
                        .font(.headline)
                        .lineLimit(1)
                    Text(isStale ? JourneyActivityAttributes.staleText : attributes.detail(for: state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(attributes.distanceText(for: state))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .accessibilityLabel(attributes.spokenDistance(for: state))
            }
            StepProgress(count: attributes.steps.count, current: state.stepIndex, hasArrived: state.hasArrived)
            if !state.hasArrived {
                JourneyButtons()
            }
        }
        .padding(16)
    }
}

/// Uygulamayı açmadan "Sonraki adım" ve "Bitir". Intent'ler (`LiveActivityIntent`)
/// uygulamanın sürecinde çalışır; sistem gerekirse uygulamayı arka planda açar.
private struct JourneyButtons: View {
    var body: some View {
        HStack(spacing: 8) {
            Button(intent: AdvanceJourneyIntent()) {
                Label("Sonraki adım", systemImage: "forward.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.accentColor)
            Button(intent: EndJourneyIntent()) {
                Label("Bitir", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.red)
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
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
    JourneyActivityAttributes.ContentState(stepIndex: 1, metersRemaining: 2_300, isOffRoute: true)
    JourneyActivityAttributes.ContentState(stepIndex: 2, hasArrived: true)
}
