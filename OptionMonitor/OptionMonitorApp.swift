import SwiftUI

@main
struct OptionMonitorApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        // Request notification permissions on app launch
        NotificationService.shared.requestAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            SummaryListView()
                .onChange(of: scenePhase) { newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        // Note: WebSocket connection management is handled in SummaryListView
        // This is here for potential future app-level lifecycle management
        switch phase {
        case .background:
            // App moved to background - connection will be managed by view
            break
        case .active:
            // App became active - connection will be managed by view
            break
        case .inactive:
            // App became inactive
            break
        @unknown default:
            break
        }
    }
}

