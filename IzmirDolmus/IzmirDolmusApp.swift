import SwiftUI

@main
struct IzmirDolmusApp: App {
    @State private var store = DataStore()
    @State private var router = Router()
    @State private var user = UserStore()
    @State private var fares = FareStore()
    @State private var events = EventsStore()
    @State private var feedback = FeedbackStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(user)
                .environment(fares)
                .environment(events)
                .environment(feedback)
        }
    }
}
