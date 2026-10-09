//
//  RootView.swift
//  IzmirDolmus
//
//  Created by Baran Göcen on 8.10.2026.
//

import SwiftUI
import DolmusCore

struct RootView: View {
    @State private var store = DataStore()

    var body: some View {
        List(store.hats) { hat in
            HatRow(hat: hat)
        }
        .overlay {
            switch store.phase {
            case .idle, .loading:
                ProgressView("Hatlar yükleniyor…")
            case .failed(let message):
                ContentUnavailableView(
                    "Veri yüklenemedi",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded:
                EmptyView()
            }
        }
        .safeAreaInset(edge: .top, alignment: .leading) {
            Text("İzmir Dolmuş")
                .font(.custom("Figtree-ExtraBold", size: 30, relativeTo: .largeTitle))
                .foregroundStyle(.tint)
                .padding(.horizontal)
        }
        .task {
            await store.load()
        }
    }
}

#Preview {
    RootView()
}
