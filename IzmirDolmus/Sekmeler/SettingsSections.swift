import DolmusCore
import SwiftUI

/// "Son aramalar": yer aramasında seçilen yerler (Faz 5-6'da dolmaya başlar).
struct RecentPlacesSection: View {
    @Environment(UserStore.self) private var user

    var body: some View {
        Section("Son aramalar") {
            if user.recentPlaces.isEmpty {
                Text("Henüz arama yok.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(user.recentPlaces, id: \.self) { place in
                    Label(place.label, systemImage: "clock.arrow.circlepath")
                }
                Button("Geçmişi temizle", role: .destructive) {
                    user.clearRecents()
                }
            }
        }
    }
}

/// "Hakkında": hat sayısı, kapsam, sürüm ve uyarı.
struct AboutSection: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        Section {
            LabeledContent("Hat sayısı", value: "\(store.data.hats.count) ana hat")
            LabeledContent("Kapsam", value: "İzmir geneli")
            LabeledContent("Sürüm", value: appVersion)
        } header: {
            Text("Hakkında")
        } footer: {
            Text("Ücretler ve süreler yaklaşıktır; kesin bilgi için şoföre danışın. Resmi bir İBB uygulaması değildir.")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}
