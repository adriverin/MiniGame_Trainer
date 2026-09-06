import SwiftUI

@main
struct MiniGameTrainerApp: App {
    @StateObject private var environment: AppEnvironment
    @StateObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let environment = AppEnvironment()
        _environment = StateObject(wrappedValue: environment)
        _router = StateObject(wrappedValue: AppRouter(attemptManager: environment.attemptManager))
    }

    var body: some Scene {
        WindowGroup {
            launchContent
                .environmentObject(router)
                .environmentObject(environment)
                .environmentObject(environment.statisticsStore)
                .environmentObject(environment.preferences)
                .environmentObject(environment.attemptManager)
                .environmentObject(environment.purchaseManager)
                .environmentObject(environment.consentManager)
                .environmentObject(environment.rewardedAdManager)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        environment.attemptManager.refreshForCalendarChange()
                    }
                }
                .task {
                    #if DEBUG
                    guard !LaneRushCheckpointLaunch.isEnabled else { return }
                    #endif
                    await environment.startMonetization()
                    DebugLaunchOptions.apply(router: router, environment: environment)
                }
        }
    }

    @ViewBuilder
    private var launchContent: some View {
        #if DEBUG
        if LaneRushCheckpointLaunch.isEnabled {
            LaneRushStaticRoadView(
                vehicleDepth: LaneRushVehicleDepth.launchValue(),
                playerCheckpoint: LaneRushPlayerCheckpoint.launchValue()
            )
        } else {
            RootView()
        }
        #else
        RootView()
        #endif
    }
}
