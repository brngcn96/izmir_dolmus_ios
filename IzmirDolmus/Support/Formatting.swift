import Foundation

extension Locale {
    /// Uygulama yalnızca Türkçe; tarihler cihazın bölge ayarından bağımsız
    /// Türkçe yazılır.
    static let turkish = Locale(identifier: "tr_TR")
}

extension Date {
    /// "15 Eki 2026 14:03".
    var turkishDateTime: String {
        formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(.turkish))
    }

    /// "3 saat önce", "dün".
    var turkishRelative: String {
        formatted(.relative(presentation: .named).locale(.turkish))
    }
}
