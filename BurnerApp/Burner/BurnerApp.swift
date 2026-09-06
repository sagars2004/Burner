import SwiftUI

@main
struct BurnerApp: App {
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
