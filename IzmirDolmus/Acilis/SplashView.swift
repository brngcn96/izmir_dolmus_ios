import SwiftUI

/// Açılış: turkuaz dolmuş soldan kayarak gelir, "İzmir Dolmuş" yazısı belirip
/// hafifçe yukarı kayar (Flutter'daki `SplashScreen`). Bu sırada veri yüklenir;
/// ne zaman geçileceğine `RootView` karar verir.
struct SplashView: View {
    /// Animasyonun süresi; `RootView` en az bu kadar bekler.
    static let duration: Duration = .milliseconds(1600)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trigger = false
    /// Yükleme uzun sürerse altta "Yükleniyor…" belirir.
    @State private var isShowingProgress = false

    /// Animasyonun her karedeki değerleri.
    private struct Frame {
        /// Dolmuşun yatay konumu, ekran genişliği cinsinden: -1 sol dışarıda, 0 yerinde.
        var busOffset = -1.0
        var textOpacity = 0.0
        /// Yazının aşağıdan yukarı kayışı (pt).
        var textOffset = 14.0
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            KeyframeAnimator(initialValue: reduceMotion ? Frame(busOffset: 0) : Frame(), trigger: trigger) { frame in
                VStack(spacing: 8) {
                    Image(.dolmus)
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(width * 0.72, 420))
                        // Görselin üstü ve altı saydam: yazıyı dolmuşa yaklaştır.
                        .padding(.vertical, -min(width * 0.72, 420) * 0.2)
                        .offset(x: frame.busOffset * width)
                    VStack(spacing: 6) {
                        Text("İzmir Dolmuş")
                            .font(.figtree(.title, weight: .extraBold))
                            .kerning(-0.5)
                        Text("Hatlar, güzergah ve yol tarifi")
                            .font(.figtree(.footnote, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .opacity(frame.textOpacity)
                    .offset(y: frame.textOffset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } keyframes: { _ in
                // Kübik anahtar karede başlangıç hızı 3 × yol ÷ süre, bitiş hızı 0:
                // eğri tam olarak "easeOutCubic" olur (hızlı başlar, yavaşça durur).
                KeyframeTrack(\.busOffset) {
                    CubicKeyframe(0, duration: 1.6, startVelocity: 3 / 1.6, endVelocity: 0)
                }
                // Yazı animasyonun %35'inde başlar.
                KeyframeTrack(\.textOpacity) {
                    LinearKeyframe(0, duration: 0.56)
                    CubicKeyframe(1, duration: 1.04, startVelocity: 3 / 1.04, endVelocity: 0)
                }
                KeyframeTrack(\.textOffset) {
                    LinearKeyframe(14, duration: 0.56)
                    CubicKeyframe(0, duration: 1.04, startVelocity: -3 * 14 / 1.04, endVelocity: 0)
                }
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                ProgressView()
                Text("Yükleniyor…")
                    .font(.figtree(.footnote, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 44)
            .opacity(isShowingProgress ? 1 : 0)
            .animation(.easeOut(duration: 0.35), value: isShowingProgress)
        }
        // Sistemin açılış ekranıyla aynı zemin: geçiş dikişsiz.
        .background(Color(uiColor: .systemBackground))
        .accessibilityElement(children: .combine)
        .onAppear {
            trigger.toggle()
        }
        .task {
            try? await Task.sleep(for: Self.duration + .milliseconds(500))
            isShowingProgress = true
        }
    }
}

#Preview {
    SplashView()
}
