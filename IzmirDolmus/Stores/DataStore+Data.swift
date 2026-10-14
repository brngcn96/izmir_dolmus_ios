import DolmusCore

extension DataStore {
    /// Yüklenmiş veri; henüz hazır değilse boş veri. Sekmeler ancak yükleme
    /// bitince gösterildiği için ekranlar veriyi `Optional` açmadan okur.
    var data: DolmusData {
        if case .loaded(let data) = phase { data } else { .empty }
    }
}
