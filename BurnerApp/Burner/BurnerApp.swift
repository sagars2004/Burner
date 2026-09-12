import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure regular application policy so it appears in the macOS Dock
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = BurnerIconRenderer.createDockIcon()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}

@main
struct BurnerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var apiService = BurnerAPIService()

    var body: some Scene {
        MenuBarExtra {
            MainPopoverView(apiService: apiService)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: apiService.menuBarIcon)
                if let warning = apiService.lowestQuotaWarning {
                    Text(warning)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
