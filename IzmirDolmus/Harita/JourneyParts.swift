import DolmusCore
import MapKit
import SwiftUI

extension Journey {
    /// "~42 dk · 40–60 ₺"
    var summary: String {
        "~\(estimatedMinutes) dk · \(feeLabel)"
    }

    var transfersLabel: String {
        transfers == 0 ? "aktarmasız" : "\(transfers) aktarma"
    }

    /// Bacakların sırası ve dolmuş bacaklarının kaçıncı dolmuş olduğu (renk için).
    var numberedLegs: [(offset: Int, leg: JourneyLeg, ride: Int)] {
        var rideNumber = 0
        return legs.enumerated().map { offset, leg in
            defer { if case .ride = leg { rideNumber += 1 } }
            return (offset, leg, rideNumber)
        }
    }
}

extension MapModel {
    static func rideColor(_ number: Int) -> Color {
        rideColors[number % rideColors.count]
    }
}

/// Bacakların şeridi: yürüme metresi → dolmuş adı → …
struct JourneyStripe: View {
    let journey: Journey

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(journey.numberedLegs, id: \.offset) { item in
                HStack(spacing: 4) {
                    if item.offset > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    switch item.leg {
                    case .walk(let walk):
                        Label("\(Int(walk.meters.rounded())) m", systemImage: "figure.walk")
                            .font(.figtree(.caption, weight: .semibold))
                            .foregroundStyle(.secondary)
                    case .ride(let ride):
                        Label(ride.hatName, systemImage: "bus.fill")
                            .font(.figtree(.caption, weight: .bold))
                            .foregroundStyle(MapModel.rideColor(item.ride))
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

/// Bir yol tarifi seçeneği.
struct JourneyCard: View {
    let journey: Journey
    let isRecommended: Bool
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isRecommended {
                // `Label` değil: List satırında simgesi ayrı sütuna konup rozet bozuluyor.
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                    Text("Önerilen")
                }
                .font(.figtree(.caption, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accent, in: .capsule)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("~\(journey.estimatedMinutes) dk")
                    .font(.figtree(.headline, weight: .extraBold))
                Text(journey.transfersLabel)
                    .font(.figtree(.subheadline))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(journey.feeLabel)
                    .font(.figtree(.subheadline, weight: .bold))
                    .foregroundStyle(Color.fee(journey.feeMin))
            }
            JourneyStripe(journey: journey)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(Color.accent)
                    .frame(width: 4)
                    .offset(x: -12)
            }
        }
    }
}

/// Seçenekler listesi (en iyi önce).
struct JourneyListSheet: View {
    let model: MapModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(model.journeys.enumerated()), id: \.element.id) { index, journey in
                        Button {
                            model.selectJourney(index)
                        } label: {
                            JourneyCard(journey: journey, isRecommended: index == 0, isSelected: index == model.journeyIndex)
                                .foregroundStyle(Color.primary)
                        }
                    }
                } footer: {
                    Text("Süreler ve ücretler yaklaşıktır (sefer saati verisi yok). Dolmuşlar güzergah üzerinde uygun yerde bindirir ve indirir.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var title: String {
        guard let from = model.tripFrom, let to = model.tripTo else { return "Seçenekler" }
        return "\(from.label) → \(to.label)"
    }
}

/// Seçili tarifin özeti: süre, ücret, şerit; adımlar ve seçenekler.
struct JourneyBanner: View {
    let model: MapModel

    @Environment(JourneySession.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isPlanning {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Rota hesaplanıyor…")
                        .font(.figtree(.headline))
                }
            } else if let journey = model.selectedJourney {
                HStack(alignment: .firstTextBaseline) {
                    Text(journey.summary)
                        .font(.figtree(.headline, weight: .extraBold))
                    Text(journey.transfersLabel)
                        .font(.figtree(.subheadline))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if model.journeyIndex == 0 {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.accent)
                            .accessibilityLabel("Önerilen")
                    }
                }
                JourneyStripe(journey: journey)
                HStack(spacing: 10) {
                    Button {
                        model.isShowingSteps = true
                    } label: {
                        Label("Adım adım", systemImage: "list.number")
                            .font(.figtree(.subheadline, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary)
                    if model.journeys.count > 1 {
                        Button {
                            model.isShowingJourneyList = true
                        } label: {
                            Label("Seçenekler (\(model.journeys.count))", systemImage: "arrow.triangle.branch")
                                .font(.figtree(.subheadline, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
                journeyModeControls(journey)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.sheet))
        .padding(.horizontal, 12)
    }
}

extension JourneyBanner {
    /// Yolculuk modu: başlat; sürerken sıradaki adım ve bitir.
    @ViewBuilder
    private func journeyModeControls(_ journey: Journey) -> some View {
        if session.isActive {
            HStack(spacing: 10) {
                Button {
                    Task { await session.advance() }
                } label: {
                    Label("Sonraki adım", systemImage: "forward.fill")
                        .font(.figtree(.subheadline, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                Button(role: .destructive) {
                    Task { await session.end() }
                } label: {
                    Label("Bitir", systemImage: "stop.fill")
                        .font(.figtree(.subheadline, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .glassEffect(.regular.interactive(), in: .capsule)
            }
        } else {
            Button {
                if let from = model.tripFrom, let to = model.tripTo {
                    session.start(journey: journey, from: from, to: to)
                }
            } label: {
                Label("Yolculuğu başlat", systemImage: "location.north.line.fill")
                    .font(.figtree(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
        }
        if let message = session.errorMessage {
            Text(message)
                .font(.figtree(.footnote))
                .foregroundStyle(.red)
        }
    }
}

/// Adım adım tarif: yürü, bin, aktar, in.
struct JourneyStepsSheet: View {
    let journey: Journey

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(journey.numberedLegs, id: \.offset) { item in
                        step(item.offset, item.leg, ride: item.ride)
                    }
                } header: {
                    Text("\(journey.summary) · \(journey.transfersLabel)")
                        .font(.figtree(.subheadline, weight: .semibold))
                } footer: {
                    Text("Yürüme mesafeleri kuş uçuşu tahminidir; gerçek yaya yolu için Apple Haritalar'da aç.")
                }
            }
            .navigationTitle("Adım adım")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func step(_ offset: Int, _ leg: JourneyLeg, ride number: Int) -> some View {
        switch leg {
        case .walk(let walk):
            let isTransfer = offset > 0 && offset < journey.legs.count - 1
            let meters = Int(walk.meters.rounded())
            let title = isTransfer
                ? "Aktarma için \(meters) m yürü"
                : offset == 0 ? "\(meters) m yürü — dolmuş durağına" : "Varışa \(meters) m yürü"
            HStack(alignment: .top, spacing: 12) {
                stepIcon("figure.walk", color: .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.figtree(.subheadline, weight: .semibold))
                    Text(isTransfer ? "\(walk.toLabel) hattına" : walk.toLabel)
                        .font(.figtree(.footnote))
                        .foregroundStyle(.secondary)
                    Button {
                        openInMaps(walk)
                    } label: {
                        Label("Haritalar'da aç", systemImage: "map")
                            .font(.figtree(.footnote, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 2)
                }
            }
        case .ride(let ride):
            let fee: String = switch (ride.feeMin, ride.feeMax) {
            case let (min?, max?) where min != max: " · \(min)–\(max) ₺"
            case let (min?, _): " · \(min) ₺"
            default: ""
            }
            let kilometers = (ride.meters / 1000).formatted(.number.precision(.fractionLength(1)).locale(.turkish))
            HStack(alignment: .top, spacing: 12) {
                stepIcon("bus.fill", color: MapModel.rideColor(number))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ride.hatName) dolmuşuna bin")
                        .font(.figtree(.subheadline, weight: .bold))
                    Text("~\(kilometers) km · ~\(ride.minutes) dk\(fee)")
                        .font(.figtree(.footnote))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func stepIcon(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.14), in: .circle)
    }

    /// Yürüme bacağını Apple Haritalar'da yaya yol tarifiyle açar (gerçek yaya
    /// yolu, çit ve geçişler Haritalar'ın bilgisi).
    private func openInMaps(_ walk: WalkLeg) {
        let source = MKMapItem(location: CLLocation(latitude: walk.from.latitude, longitude: walk.from.longitude), address: nil)
        let destination = MKMapItem(location: CLLocation(latitude: walk.to.latitude, longitude: walk.to.longitude), address: nil)
        destination.name = walk.toLabel
        MKMapItem.openMaps(with: [source, destination], launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
