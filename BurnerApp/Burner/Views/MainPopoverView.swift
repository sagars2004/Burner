import SwiftUI

public struct MainPopoverView: View {
    @ObservedObject public var apiService: BurnerAPIService
    @AppStorage("isBurnerExpanded") private var isExpanded: Bool = false
    @State private var selectedTab: Int = 0

    public init(apiService: BurnerAPIService) {
        self.apiService = apiService
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Navigation Bar
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)

                    Text("Burner")
                        .font(.system(size: 16, weight: .bold))

                    Circle()
                        .fill(apiService.overallStatus.color)
                        .frame(width: 8, height: 8)

                    Text(apiService.overallStatus.rawValue.capitalized)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(apiService.overallStatus.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(apiService.overallStatus.color.opacity(0.15))
                        .cornerRadius(4)
                }

                Spacer()

                HStack(spacing: 10) {
                    // Expand / Collapse Size Toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded ? "Collapse Panel" : "Expand Panel")

                    // Manual Refresh Button
                    Button(action: {
                        Task {
                            await apiService.fetchStatus()
                            await apiService.requestRecommendation(taskType: apiService.selectedTaskType)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh Quotas Now")

                    // Quit Button
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Quit Burner (Cmd+Q)")
                }
            }
            .padding(.bottom, 2)

            // View Mode Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("5 Providers (\(apiService.providers.count))").tag(1)
                Text("AI Agent").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)

            // Backend Connection Warning (if offline)
            if !apiService.isServerConnected {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                    Text("Backend disconnected on port 8000")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Button("Reconnect") {
                        Task { await apiService.fetchStatus() }
                    }
                    .font(.system(size: 11, weight: .bold))
                }
                .padding(8)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(6)
            }

            // Main Content Area with ScrollView
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    
                    if selectedTab == 0 {
                        // TAB 0: OVERVIEW (Agent Deck + All 5 Providers + Drawer)
                        AgentRecommendationDeck(apiService: apiService)

                        HStack {
                            Text("CONNECTED PROVIDERS (\(apiService.providers.count))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Auto-refresh: 8s")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        VStack(spacing: 8) {
                            ForEach(apiService.providers) { provider in
                                ProviderTileView(provider: provider)
                            }
                        }

                        Divider()
                            .padding(.vertical, 2)

                        DemoSimulationDrawer(apiService: apiService)

                    } else if selectedTab == 1 {
                        // TAB 1: DEDICATED PROVIDERS TAB (Large detail cards)
                        HStack {
                            Text("ALL AI CODING QUOTAS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("5 Connected")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        VStack(spacing: 9) {
                            ForEach(apiService.providers) { provider in
                                ProviderTileView(provider: provider)
                            }
                        }

                        Divider()
                            .padding(.vertical, 4)

                        DemoSimulationDrawer(apiService: apiService)

                    } else {
                        // TAB 2: DEDICATED AI AGENT TAB
                        AgentRecommendationDeck(apiService: apiService)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("MULTI-FACTOR ROUTING LOGIC")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Label("Quick edits are routed to Cursor / Copilot to preserve high-context quotas.", systemImage: "bolt.fill")
                                Label("Deep architectural refactors prioritize Claude 3.5 Sonnet & Gemini Pro.", systemImage: "brain.head.profile")
                                Label("Rapid burn rate (<25% quota) automatically triggers limit avoidance.", systemImage: "exclamationmark.shield.fill")
                            }
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .padding(9)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(7)
                        }

                        Divider()
                            .padding(.vertical, 2)

                        DemoSimulationDrawer(apiService: apiService)
                    }
                }
                .padding(.trailing, 2)
            }

            Divider()

            // Footer Info
            HStack {
                Text("Burner v1.0 • AI Builders Hackathon")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Panel: \(isExpanded ? "Expanded" : "Standard")")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(
            width: isExpanded ? 520 : 430,
            height: isExpanded ? 760 : 640
        )
    }
}
