import SwiftUI
import AppKit

@main
struct LiveWallpaperApp: App {
    // The app is driven from AppDelegate because it runs as a menu bar utility.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
