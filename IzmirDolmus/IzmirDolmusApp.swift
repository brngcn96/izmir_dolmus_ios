import SwiftUI

@main
struct IzmirDolmusApp: App {
    @State private var store = DataStore()
    @State private var router = Router()
    @State private var user = UserStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(user)
        }
    }
}
