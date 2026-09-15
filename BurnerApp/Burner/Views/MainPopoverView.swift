import SwiftUI

public enum SideDrawerTab {
    case none
    case providers
    case optimizer
    case handoff
    case trimmer
    case planner
}

public struct MainPopoverView: View {
    @ObservedObject public var apiService: BurnerAPIService
    @ObservedObject private var resizeManager = WindowResizeManager.shared
    @ObservedObject private var sidePanelManager = SidePanelManager.shared

    @State private var isAgentExpanded: Bool = true
    @State private var showCustomPromptInput: Bool = false
    @State private var customPromptText: String = ""

    public init(apiService: BurnerAPIService) {
        self.apiService = apiService
    }

    public var body: some View {
        mainPanelContent
            .frame(width: resizeManager.currentWidth, height: resizeManager.currentHeight)
            .background(Color(red: 0.08, green: 0.08, blue: 0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .background(
                WindowAccessor { window in
                    resizeManager.attach(window: window)
                    sidePanelManager.mainWindow = window
                    sidePanelManager.apiService = apiService
                }
            )
    }

    // MARK: - Main Panel View Content
    private var mainPanelContent: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.orange)

                    Text("Burner")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize()

                    Circle()
                        .fill(apiService.overallStatus.color)
                        .frame(width: 6, height: 6)

                    Text(apiService.overallStatus.rawValue.capitalized)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(apiService.overallStatus.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(apiService.overallStatus.color.opacity(0.15))
                        .cornerRadius(4)
                        .lineLimit(1)
                        .fixedSize()
                }

                Spacer()

                HStack(spacing: 5) {
                    // Optimizer Button (Cyan)
                    Button(action: {
                        sidePanelManager.toggle(tab: .optimizer)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 9.5, weight: .bold))
                            Text("Optimizer")
                                .font(.system(size: 10.5, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(sidePanelManager.activeTab == .optimizer ? Color.cyan : Color.cyan.opacity(0.18))
                        .foregroundColor(sidePanelManager.activeTab == .optimizer ? .black : .cyan)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Open AI Prompt Optimizer on left")

                    // Hot-Swap Button (Orange)
                    let isAnyCritical = apiService.providers.contains(where: { $0.status == .critical || $0.status == .exhausted })
                    Button(action: {
                        sidePanelManager.toggle(tab: .handoff)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 9.5, weight: .bold))
                            Text("Hot-Swap")
                                .font(.system(size: 10.5, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(
                            sidePanelManager.activeTab == .handoff
                                ? Color.orange
                                : (isAnyCritical ? Color.orange.opacity(0.3) : Color.orange.opacity(0.15))
                        )
                        .foregroundColor(sidePanelManager.activeTab == .handoff ? .black : .orange)
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isAnyCritical ? Color.orange.opacity(0.7) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Hot-Swap Handoff Capsule: zero-loss model transition")

                    // Trimmer Button (Green)
                    Button(action: {
                        sidePanelManager.toggle(tab: .trimmer)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "scissors")
                                .font(.system(size: 9.5, weight: .bold))
                            Text("Trimmer")
                                .font(.system(size: 10.5, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(sidePanelManager.activeTab == .trimmer ? Color.green : Color.green.opacity(0.18))
                        .foregroundColor(sidePanelManager.activeTab == .trimmer ? .black : Color(red: 0.3, green: 0.9, blue: 0.6))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Code Trimmer & Token Reducer (-60% to -80% prompt burn)")

                    // Planner Button (Purple)
                    Button(action: {
                        sidePanelManager.toggle(tab: .planner)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 9.5, weight: .bold))
                            Text("Planner")
                                .font(.system(size: 10.5, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(sidePanelManager.activeTab == .planner ? Color.purple : Color.purple.opacity(0.18))
                        .foregroundColor(sidePanelManager.activeTab == .planner ? .black : Color(red: 0.8, green: 0.6, blue: 1.0))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Autonomous Sprint Token Planner: multi-model pipeline")

                    // Refresh Button
                    Button(action: {
                        Task {
                            await apiService.fetchStatus()
                            await apiService.requestRecommendation(taskType: apiService.selectedTaskType)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh Quotas")

                    // Quit Button
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                    .help("Quit Burner")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.35))

            Divider().background(Color.white.opacity(0.08))

            // Disconnected Banner (if backend is unreachable)
            if !apiService.isServerConnected {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text("Backend disconnected on port 8000 — reconnecting...")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Spacer()
                    Button("Retry") {
                        Task { await apiService.fetchStatus() }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.orange.opacity(0.12))
            }

            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // MARK: - AI Agent Routing Card
                    VStack(spacing: 10) {
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isAgentExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isAgentExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.gray)

                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12))
                                        .foregroundColor(.cyan)

                                    Text("AUTONOMOUS ROUTING AGENT")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundColor(.gray)
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            if let rec = apiService.activeRecommendation {
                                Text("\(Int(rec.confidence * 100))% confidence")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.cyan.opacity(0.85))
                            }
                        }

                        if isAgentExpanded {
                            VStack(alignment: .leading, spacing: 9) {
                                // Task Selector Chips
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(TaskType.allCases) { t in
                                            Button(action: {
                                                Task {
                                                    await apiService.requestRecommendation(taskType: t)
                                                }
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: t.icon)
                                                        .font(.system(size: 9.5))
                                                    Text(t.title)
                                                        .font(.system(size: 11, weight: apiService.selectedTaskType == t ? .bold : .regular))
                                                        .lineLimit(1)
                                                        .fixedSize(horizontal: true, vertical: false)
                                                }
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 4.5)
                                                .background(apiService.selectedTaskType == t ? Color.cyan.opacity(0.25) : Color.white.opacity(0.04))
                                                .foregroundColor(apiService.selectedTaskType == t ? .cyan : .white.opacity(0.8))
                                                .cornerRadius(6)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(apiService.selectedTaskType == t ? Color.cyan.opacity(0.4) : Color.clear, lineWidth: 1)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                // Custom Prompt Analysis Toggle
                                HStack {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showCustomPromptInput.toggle()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: showCustomPromptInput ? "chevron.down" : "text.magnifyingglass")
                                                .font(.system(size: 9))
                                            Text(showCustomPromptInput ? "Hide prompt analysis" : "Analyze specific task / prompt...")
                                                .font(.system(size: 10))
                                        }
                                        .foregroundColor(.cyan.opacity(0.85))
                                    }
                                    .buttonStyle(.plain)

                                    Spacer()
                                }

                                if showCustomPromptInput {
                                    HStack(spacing: 6) {
                                        TextField("e.g. Refactor authentication module to OAuth2", text: $customPromptText)
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 11))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(5)
                                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.12), lineWidth: 1))

                                        Button(action: {
                                            Task {
                                                await apiService.requestRecommendation(
                                                    taskType: apiService.selectedTaskType,
                                                    prompt: customPromptText
                                                )
                                            }
                                        }) {
                                            Text("Evaluate")
                                                .font(.system(size: 10.5, weight: .bold))
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 5)
                                                .background(Color.cyan)
                                                .foregroundColor(.black)
                                                .cornerRadius(5)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.top, 1)
                                }

                                // Recommendation Narrative
                                if let rec = apiService.activeRecommendation {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(rec.headline)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text(rec.suggested_model)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.cyan)
                                        }

                                        Text(rec.reasoning)
                                            .font(.system(size: 11.5))
                                            .foregroundColor(.white.opacity(0.85))
                                            .lineSpacing(3)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if let warning = rec.burn_rate_warning {
                                            HStack(spacing: 5) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.orange)
                                                Text(warning)
                                                    .font(.system(size: 10.5, weight: .semibold))
                                                    .foregroundColor(.orange)
                                            }
                                            .padding(.top, 2)
                                        }
                                    }
                                    .padding(11)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(10)

                    // MARK: - Providers Quotas List
                    VStack(spacing: 9) {
                        HStack {
                            Text("AI CODING QUOTAS (\(apiService.providers.count) VISIBLE)")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.gray)

                            Spacer()

                            Button(action: {
                                sidePanelManager.toggle(tab: .providers)
                            }) {
                                HStack(spacing: 3) {
                                    Text("Filter Tools")
                                        .font(.system(size: 10.5, weight: .medium))
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 9))
                                }
                                .foregroundColor(.cyan)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 2)

                        if apiService.providers.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "eye.slash")
                                    .font(.system(size: 22))
                                    .foregroundColor(.gray)
                                Text("All providers are currently hidden.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Button("Open Provider Manager") {
                                    sidePanelManager.toggle(tab: .providers)
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.cyan)
                            }
                            .padding(28)
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(apiService.providers) { provider in
                                    CodexProviderRow(
                                        provider: provider,
                                        forecast: apiService.forecastFor(providerId: provider.provider_id),
                                        onLaunch: {
                                            Task {
                                                await apiService.launchTarget(providerId: provider.provider_id)
                                            }
                                        }
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Hackathon Demo Simulation Controls
                    DemoSimulationDrawer(apiService: apiService)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().background(Color.white.opacity(0.08))

            // Footer Bar
            HStack(spacing: 12) {
                Button(action: {
                    sidePanelManager.toggle(tab: .providers)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10.5))
                        Text(sidePanelManager.activeTab == .providers ? "Hide Tools" : "Manage Tools")
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(sidePanelManager.activeTab == .providers ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                    .foregroundColor(sidePanelManager.activeTab == .providers ? .white : .gray)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Manage Detected AI Tools & Quotas")

                Spacer()

                Text("Updated just now")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.7))
            }
            .padding(.leading, 14)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.25))
            .overlay {
                CornerResizeGrip()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
