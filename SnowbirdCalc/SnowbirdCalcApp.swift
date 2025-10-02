import SwiftUI

@main
struct SnowbirdApp: App {
    @StateObject private var appVM = AppViewModel()
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appVM)
        }
    }
}
