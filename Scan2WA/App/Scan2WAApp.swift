import SwiftUI

@main
struct Scan2WAApp: App {
    var body: some Scene {
        WindowGroup {
            MainScannerView()
                .preferredColorScheme(.dark)
        }
    }
}
