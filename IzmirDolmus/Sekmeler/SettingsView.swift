import DolmusCore
import SwiftUI

/// Ayarlar: kayıtlı adresler (Ev/İş), son aramalar, ücretler, hakkında.
struct SettingsView: View {
    @Environment(UserStore.self) private var user

    @State private var editing: SavedPlaceKind?

    var body: some View {
        @Bindable var user = user
        List {
            Section("Kayıtlı adresler") {
                SavedPlaceRow(kind: .home, place: user.home) { editing = .home }
                SavedPlaceRow(kind: .work, place: user.work) { editing = .work }
            }
            RecentPlacesSection()
            FaresSection()
            AboutSection()
        }
        .navigationTitle("Ayarlar")
        .sheet(item: $editing) { kind in
            switch kind {
            case .home:
                PlacePickerView(kind: .home, selection: $user.home)
            case .work:
                PlacePickerView(kind: .work, selection: $user.work)
            }
        }
    }
}
