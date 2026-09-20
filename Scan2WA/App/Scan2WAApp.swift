import SwiftUI

@main
struct Scan2WAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var navigationState = AppNavigationState.shared

    var body: some Scene {
        WindowGroup {
            MainScannerView()
                .environmentObject(navigationState)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    navigationState.handleOpenURL(url)
                }
        }
    }
}
