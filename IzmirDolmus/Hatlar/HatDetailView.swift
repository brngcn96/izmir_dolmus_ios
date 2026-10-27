import DolmusCore
import SwiftUI

/// Hat detayı: özet, kilit noktalar, ücret bölgeleri ve geri bildirim. Bir
/// ücret bölgesine dokununca güzergahındaki noktalar alt sayfada açılır.
struct HatDetailView: View {
    let hat: DolmusHat

    @State private var selectedSegment: DolmusRoute?

    var body: some View {
        List {
            HatSummarySections(hat: hat)
            FareRowsSection(segments: hat.segments) { segment in
                selectedSegment = segment
            }
            HatFeedbackSection(hat: hat)
        }
        .navigationTitle(hat.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSegment) { segment in
            FareSheet(segment: segment)
                .presentationDetents([.medium, .large])
        }
    }
}
