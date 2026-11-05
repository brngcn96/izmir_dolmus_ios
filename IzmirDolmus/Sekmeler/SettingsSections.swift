import DolmusCore
import SwiftUI

/// "Son aramalar": yer aramasında seçilen yerler (Faz 5-6'da dolmaya başlar).
struct RecentPlacesSection: View {
    @Environment(UserStore.self) private var user

    var body: some View {
        Section("Son aramalar") {
            if user.recentPlaces.isEmpty {
                Text("Henüz arama yok.")
                    .foregroundStyle(.textSecondary)
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

/// "Görünüm": asıl tema açık; istenirse cihazın koyu modu izlenir.
struct AppearanceSection: View {
    static let followsSystemKey = "appearance_follows_system"

    @AppStorage(Self.followsSystemKey, store: AppEnvironment.defaults) private var followsSystem = false

    var body: some View {
        Section {
            Toggle("Cihazın koyu modunu kullan", isOn: $followsSystem)
        } header: {
            Text("Görünüm")
        } footer: {
            Text("Kapalıyken uygulama hep açık temada görünür; açıkken cihaz koyu moddaysa koyu temaya geçer.")
        }
    }
}

/// "Hakkında": hat sayısı, kapsam, sürüm, lisanslar, reklam rızası ve uyarı.
struct AboutSection: View {
    @Environment(DataStore.self) private var store
    @Environment(AdsController.self) private var ads

    var body: some View {
        Section {
            LabeledContent("Hat sayısı", value: "\(store.data.hats.count) ana hat")
            LabeledContent("Kapsam", value: "İzmir geneli")
            LabeledContent("Sürüm", value: appVersion)
            NavigationLink("Lisanslar ve kaynaklar", value: Route.licenses)
            // Yalnızca rızanın gerektiği yerlerde (AB, Birleşik Krallık): Google'ın formu.
            if ads.isPrivacyOptionsRequired {
                Button("Reklam gizlilik seçenekleri") {
                    Task { await ads.presentPrivacyOptions() }
                }
            }
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
