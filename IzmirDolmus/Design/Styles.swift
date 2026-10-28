import SwiftUI

/// Kart görünümü: yüzey rengi, yuvarlatılmış köşeler, iç boşluk.
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface, in: .rect(cornerRadius: Theme.Radius.card))
    }
}

extension View {
    /// View'ı kart olarak çizer (bkz. `CardModifier`).
    func card() -> some View {
        modifier(CardModifier())
    }
}

/// Ana eylem button'u: marka renginde dolu kapsül, basılınca hafifçe küçülür.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.figtree(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            // Kapalıyken soluk ama opak: klavyenin üstünde dururken altındaki
            // liste içinden görünmesin.
            .background(isEnabled ? Color.accent : Color.accent.mix(with: Color(uiColor: .systemBackground), by: 0.6), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    /// `.buttonStyle(.primary)` diye yazılabilsin diye.
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
