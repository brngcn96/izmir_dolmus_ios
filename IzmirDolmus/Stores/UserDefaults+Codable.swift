import Foundation

extension UserDefaults {
    /// `key` altında JSON olarak saklanmış değeri okur. Kayıt yoksa ya da
    /// okunamıyorsa `nil`: bozuk ya da eski biçimdeki bir tercih uygulamayı
    /// durdurmamalı, yokmuş gibi davranılır.
    func codable<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    /// Değeri JSON olarak `key` altına yazar; `nil` ise kaydı siler.
    func setCodable<Value: Encodable>(_ value: Value?, forKey key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            removeObject(forKey: key)
            return
        }
        set(data, forKey: key)
    }
}
