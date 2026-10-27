import SwiftUI
import UIKit

/// Uzun basmanın ekrandaki yerini veren hareket. SwiftUI'ın `LongPressGesture`'ı
/// yeri vermediği için UIKit'in tanıyıcısı kullanılıyor (iOS 18+).
struct LongPressLocationGesture: UIGestureRecognizerRepresentable {
    var minimumDuration = 0.45
    var onBegan: (CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = minimumDuration
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        if recognizer.state == .began {
            onBegan(context.converter.localLocation)
        }
    }
}
