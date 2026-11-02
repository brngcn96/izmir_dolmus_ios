import DolmusCore
import SwiftUI

/// Kayıtlı adres türleri.
enum SavedPlaceKind: Identifiable {
    case home
    case work

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Ev"
        case .work: "İş"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .work: "briefcase.fill"
        }
    }

    /// Yer seçme ekranının başlığı.
    var pickerTitle: String {
        switch self {
        case .home: "Ev adresin"
        case .work: "İş adresin"
        }
    }
}

/// Ayarlar'da bir kayıtlı adres satırı; dokununca `onEdit` çağrılır.
struct SavedPlaceRow: View {
    let kind: SavedPlaceKind
    let place: PlacePoint?
    let onEdit: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))

        Button(action: onEdit) {
            layout {
                Label(kind.title, systemImage: kind.systemImage)
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(place?.label ?? "Ayarlanmadı")
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
            }
        }
    }
}

/// Kayıtlı bir adres için yer seçtirir: yer sözlüğünde arar, seçilen yeri
/// `selection`'a yazıp kapanır.
struct PlacePickerView: View {
    let kind: SavedPlaceKind
    @Binding var selection: PlacePoint?

    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let results = store.data.placeMatches(query, limit: 12, near: .izmirCenter)

        NavigationStack {
            List {
                if query.count < 3 {
                    Text("En az 3 harf yaz.")
                        .foregroundStyle(.textSecondary)
                } else {
                    ForEach(results, id: \.self) { place in
                        Button {
                            selection = place
                            dismiss()
                        } label: {
                            Label(place.label, systemImage: "mappin.and.ellipse")
                                .foregroundStyle(Color.primary)
                        }
                    }
                }
                if let current = selection {
                    Section {
                        Button("\(kind.title) adresini kaldır", role: .destructive) {
                            selection = nil
                            dismiss()
                        }
                    } footer: {
                        Text("Şu anki: \(current.label)")
                    }
                }
            }
            .overlay {
                if query.count >= 3 && results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle(kind.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Mahalle, cadde, durak…"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }
}
