import SwiftUI

/// Henüz yazılmamış bir sekmenin yer tutucusu.
struct ComingSoonView: View {
    let title: String
    let systemImage: String
    /// İçeriğin geleceği faz (bkz. PLAN.md).
    let phase: Int

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text("Faz \(phase)'te gelecek."))
            .navigationTitle(title)
    }
}
