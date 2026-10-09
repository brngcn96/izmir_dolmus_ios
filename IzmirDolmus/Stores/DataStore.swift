import DolmusCore
import Foundation
import Observation

/// Uygulama verisinin sahibi: `DolmusData`'yı bir kez yükler, yükleme durumunu
/// arayüze bildirir.
@Observable
final class DataStore {
    enum Phase {
        case idle
        case loading
        case loaded(DolmusData)
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    private let loader: DataLoader

    init(loader: DataLoader = DataLoader()) {
        self.loader = loader
    }

    /// Yüklenmiş hatlar; veri hazır değilse boş.
    var hats: [DolmusHat] {
        if case .loaded(let data) = phase { data.hats } else { [] }
    }

    /// Veriyi yükler. Tekrar çağrılabilir; yükleme bir kez yapılır.
    func load() async {
        guard case .idle = phase else { return }
        phase = .loading
        do {
            phase = .loaded(try await loader.load())
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
