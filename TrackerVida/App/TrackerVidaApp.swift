import SwiftUI

@main
struct TrackerVidaApp: App {
    @StateObject private var store = AppStore.live()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
        }
    }
}
