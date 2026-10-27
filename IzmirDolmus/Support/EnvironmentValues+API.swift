import DolmusCore
import SwiftUI

extension EnvironmentValues {
    /// View'ların doğrudan istek attığı yerlerde (hava durumu) kullanılan istemci.
    /// Önizlemede ya da testte `.environment(\.apiClient, …)` ile sahtesi verilir.
    @Entry var apiClient = APIClient()
}
