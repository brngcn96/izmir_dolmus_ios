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

/// "Ücretler": son güncelleme, elle tazeleme, ilerleme ve iptal.
struct FaresSection: View {
    @Environment(FareStore.self) private var fares
    @Environment(DataStore.self) private var store

    var body: some View {
        Section {
            LabeledContent("Son güncelleme", value: fares.updatedAt?.turkishDateTime ?? "Henüz yok")
            if case .refreshing(let done, let total) = fares.status {
                ProgressView(value: Double(done), total: Double(max(total, 1))) {
                    Text("Ücretler güncelleniyor…")
                } currentValueLabel: {
                    Text("\(done) / \(total) hat")
                        .monospacedDigit()
                }
                Button("İptal et", role: .destructive) {
                    fares.cancel()
                }
            } else {
                Button("Ücretleri şimdi güncelle") {
                    fares.refresh(codes: store.data.fareCodes)
                }
            }
        } header: {
            Text("Ücretler")
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        switch fares.status {
        case .finished(let updated, 0):
            "\(updated) hattın ücreti güncellendi."
        case .finished(0, _):
            "Ücretler alınamadı; önceki ücretler kullanılıyor. İnternet bağlantını kontrol et."
        case .finished(let updated, let failed):
            "\(updated) hattın ücreti güncellendi; \(failed) hattınki alınamadı, onlarda önceki ücret kullanılıyor."
        case .cancelled(let updated):
            "İptal edildi. Gelen \(updated) hattın ücreti bu oturumda kullanılıyor."
        case .idle, .refreshing:
            "Ücretler İzmir Büyükşehir Belediyesi'nin servisinden alınır ve 14 günde bir kendiliğinden güncellenir."
        }
    }
}

/// "Hakkında": hat sayısı, kapsam, sürüm, lisanslar ve uyarı.
struct AboutSection: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        Section {
            LabeledContent("Hat sayısı", value: "\(store.data.hats.count) ana hat")
            LabeledContent("Kapsam", value: "İzmir geneli")
            LabeledContent("Sürüm", value: appVersion)
            NavigationLink("Lisanslar ve kaynaklar", value: Route.licenses)
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
