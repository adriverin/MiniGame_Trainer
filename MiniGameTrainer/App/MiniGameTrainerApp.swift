import SwiftUI

@main
struct MiniGameTrainerApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .environmentObject(environment)
                .environmentObject(environment.statisticsStore)
                .environmentObject(environment.preferences)
                .preferredColorScheme(.dark)
                .task {
                    DebugLaunchOptions.apply(router: router)
                }
        }
    }
}
