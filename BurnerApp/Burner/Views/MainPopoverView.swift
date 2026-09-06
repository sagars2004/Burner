import SwiftUI

public struct MainPopoverView: View {
    @ObservedObject public var apiService: BurnerAPIService

    public init(apiService: BurnerAPIService) {
        self.apiService = apiService
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Navigation Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.orange)

                    Text("Burner")
                        .font(.system(size: 15, weight: .bold))

                    Circle()
                        .fill(apiService.overallStatus.color)
                        .frame(width: 7, height: 7)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        Task {
                            await apiService.fetchStatus()
                            await apiService.requestRecommendation(taskType: apiService.selectedTaskType)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh Quotas")

                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Quit Burner")
                }
            }

            // Backend Connection Warning (if offline)
            if !apiService.isServerConnected {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text("Backend disconnected (start `python3 -m uvicorn server.main:app` on port 8000)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Retry") {
                        Task { await apiService.fetchStatus() }
                    }
                    .font(.system(size: 10, weight: .semibold))
                }
                .padding(8)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }

            // Top Feature: AI Agent Recommendation Deck
            AgentRecommendationDeck(apiService: apiService)

            // Providers Section Header
            HStack {
                Text("CONNECTED PROVIDERS (\(apiService.providers.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Auto-refreshes 8s")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)

            // 5 Provider Cards (Scrollable if necessary)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 7) {
                    if apiService.providers.isEmpty {
                        // Fallback placeholder tiles while loading
                        ForEach(ProviderID.allCases) { pid in
                            HStack {
                                Image(systemName: pid.iconName)
                                Text(pid.displayName)
                                Spacer()
                                Text("Connecting...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                            .cornerRadius(6)
                        }
                    } else {
                        ForEach(apiService.providers) { provider in
                            ProviderTileView(provider: provider)
                        }
                    }
                }
            }
            .frame(maxHeight: 280)

            Divider()

            // Hackathon Simulation Drawer
            DemoSimulationDrawer(apiService: apiService)

            // Footer Info
            HStack {
                Text("Burner • AI Builders Hackathon")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text("⌘Q to quit")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(width: 330)
    }
}
