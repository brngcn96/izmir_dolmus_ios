import Foundation

extension Locale {
    /// Uygulama yalnızca Türkçe; tarihler cihazın bölge ayarından bağımsız
    /// Türkçe yazılır.
    static let turkish = Locale(identifier: "tr_TR")
}

extension Date {
    /// "3 saat önce", "dün".
    var turkishRelative: String {
        formatted(.relative(presentation: .named).locale(.turkish))
    }
}
