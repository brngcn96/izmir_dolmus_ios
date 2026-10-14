import DolmusCore
import SwiftUI

/// Hat detayının üst bölümleri: ad ve ilçe, ücret özeti, editoryal not ve
/// geçtiği kilit noktalar.
struct HatSummarySections: View {
    let hat: DolmusHat

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(hat.name)
                    .font(.title3.weight(.bold))
                if let ilce = hat.ilce, !ilce.isEmpty {
                    Text(ilce)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if hat.segments.isEmpty {
                LabeledContent("Ücret", value: "bilinmiyor")
            } else {
                LabeledContent("Ücret", value: hat.feeLabel)
                LabeledContent("Ücret bölgesi", value: "\(hat.segments.count)")
            }
        }
        if let info = hat.info {
            Section {
                Label(info, systemImage: "info.circle")
                    .font(.subheadline)
            }
        }
        if !hat.keyStopNames.isEmpty {
            Section("Geçtiği kilit noktalar") {
                Text(hat.keyStopNames.joined(separator: " · "))
                    .font(.subheadline)
            }
        }
    }
}

/// "Ücret bölgeleri" bölümü: her satır bir ücret bölgesi. Satıra dokununca
/// `onSelect` çağrılır.
struct FareRowsSection: View {
    let segments: [DolmusRoute]
    let onSelect: (DolmusRoute) -> Void

    var body: some View {
        if !segments.isEmpty {
            Section("Ücret bölgeleri") {
                ForEach(segments) { segment in
                    Button {
                        onSelect(segment)
                    } label: {
                        FareRow(segment: segment)
                    }
                }
            }
        }
    }
}

private struct FareRow: View {
    let segment: DolmusRoute

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.stops.count > 1 ? "\(segment.fromLabel) → \(segment.toLabel)" : segment.name)
                    .foregroundStyle(Color.primary)
                if segment.firstTime {
                    Text("yeni")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            Text(segment.feeText)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}

/// Bir ücret bölgesinin alt sayfası: ücret ve güzergah üzerindeki noktalar.
struct FareSheet: View {
    let segment: DolmusRoute

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Ücret", value: segment.feeText)
                    if let distanceKm = segment.distanceKm {
                        LabeledContent("Mesafe", value: "\(distanceKm.formatted(.number.precision(.fractionLength(0...1)))) km")
                    }
                }
                Section("Güzergah üzerindeki noktalar") {
                    ForEach(Array(segment.stops.enumerated()), id: \.offset) { index, stop in
                        Label {
                            Text(stop)
                        } icon: {
                            Text("\(index + 1)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(segment.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

extension DolmusRoute {
    /// "55 ₺" ya da ücret bilinmiyorsa "—".
    fileprivate var feeText: String {
        fee.map { "\($0) ₺" } ?? "—"
    }
}
