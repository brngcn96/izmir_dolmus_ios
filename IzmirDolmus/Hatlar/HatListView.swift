import DolmusCore
import SwiftUI

/// Hatlar sekmesinin kökü: arama yokken ilçe başlıkları altında açılır-kapanır
/// bölümler, arama varken eşleşen hatların düz listesi.
struct HatListView: View {
    @Environment(DataStore.self) private var store

    @State private var query = ""
    @State private var expandedDistricts: Set<String> = []

    var body: some View {
        let isSearching = !trNorm(query).isEmpty
        let results = isSearching ? store.data.searchHats(query) : []

        List {
            if isSearching {
                ForEach(results) { hat in
                    link(to: hat)
                }
            } else {
                ForEach(store.data.districts) { district in
                    Section(isExpanded: isExpanded(district.name)) {
                        ForEach(district.hats) { hat in
                            link(to: hat)
                        }
                    } header: {
                        HStack {
                            Text(district.name)
                            Spacer()
                            Text("\(district.hats.count) hat")
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Hatlar")
        // Arama alanı başlığın altında hep görünür ama kendiliğinden açılmaz: liste önce
        // bütünüyle görülür; kaydırınca klavye kapanır.
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Hat ara (ör. Buca, Karşıyaka)")
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if isSearching && results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func link(to hat: DolmusHat) -> some View {
        NavigationLink(value: Route.hat(id: hat.id)) {
            HatRow(hat: hat)
        }
    }

    /// Bir ilçenin açık/kapalı durumunu `expandedDistricts` kümesine bağlar.
    private func isExpanded(_ district: String) -> Binding<Bool> {
        Binding {
            expandedDistricts.contains(district)
        } set: { isExpanded in
            if isExpanded {
                expandedDistricts.insert(district)
            } else {
                expandedDistricts.remove(district)
            }
        }
    }
}
