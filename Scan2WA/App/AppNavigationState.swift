import Foundation
import SwiftUI
import UIKit
import Combine

public final class AppNavigationState: ObservableObject {
    public static let shared = AppNavigationState()

    @Published public var showPackagesList: Bool = false
    @Published public var autoFocusSearch: Bool = false
    @Published public var showDirectAddPackage: Bool = false

    private init() {}

    /// Handles incoming deep link URLs (e.g. scan2wa://search, scan2wa://packages, scan2wa://add)
    public func handleOpenURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "scan2wa" else { return }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        DispatchQueue.main.async {
            if host == "search" || path.contains("search") {
                self.showDirectAddPackage = false
                self.showPackagesList = true
                self.autoFocusSearch = true
            } else if host == "packages" || path.contains("packages") {
                self.showDirectAddPackage = false
                self.showPackagesList = true
                self.autoFocusSearch = false
            } else if host == "add" || host == "capture" || path.contains("add") {
                self.showPackagesList = false
                self.showDirectAddPackage = true
            }
        }
    }

    /// Handles Home Screen 3D Touch / Quick Actions
    public func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        DispatchQueue.main.async {
            switch shortcutItem.type {
            case "com.ilyassbourass.Scan2WA.search":
                self.showDirectAddPackage = false
                self.showPackagesList = true
                self.autoFocusSearch = true
            case "com.ilyassbourass.Scan2WA.addPackage":
                self.showPackagesList = false
                self.showDirectAddPackage = true
            default:
                break
            }
        }
    }
}

// MARK: - App Delegate for Quick Actions
public final class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            AppNavigationState.shared.handleShortcutItem(shortcutItem)
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

// MARK: - Scene Delegate for Background Quick Action Handlers
public final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    public func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        AppNavigationState.shared.handleShortcutItem(shortcutItem)
        completionHandler(true)
    }
}
