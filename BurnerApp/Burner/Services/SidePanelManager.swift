import SwiftUI
import AppKit
import Combine

class BurnerSidePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    override var canBecomeMain: Bool {
        return false
    }
}

public class SidePanelManager: ObservableObject {
    public static let shared = SidePanelManager()

    @Published public var activeTab: SideDrawerTab = .none

    public weak var mainWindow: NSWindow?
    private var panel: BurnerSidePanel?
    public var apiService: BurnerAPIService?

    public init() {}

    public func toggle(tab: SideDrawerTab) {
        if activeTab == tab {
            close()
        } else {
            open(tab: tab)
        }
    }

    public func close() {
        activeTab = .none
        if let p = panel {
            if let main = mainWindow {
                main.removeChildWindow(p)
            }
            p.orderOut(nil)
        }
    }

    public func open(tab: SideDrawerTab) {
        guard let main = mainWindow, let api = apiService else {
            activeTab = tab
            return
        }
        activeTab = tab

        let panelWidth: CGFloat = 380
        let mainFrame = main.frame
        let gap: CGFloat = 8
        let x = max(10, mainFrame.minX - panelWidth - gap)
        let y = mainFrame.minY
        let h = mainFrame.height

        let panelFrame = NSRect(x: x, y: y, width: panelWidth, height: h)

        if panel == nil {
            let p = BurnerSidePanel(
                contentRect: panelFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.level = main.level
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.hidesOnDeactivate = false
            self.panel = p
        }

        guard let p = panel else { return }

        // Host the SidePanelContainerView
        let sideView = SidePanelContainerView(
            apiService: api,
            activeTab: tab,
            onClose: { [weak self] in
                self?.close()
            }
        )

        p.contentView = NSHostingView(rootView: sideView)
        p.setFrame(panelFrame, display: true, animate: false)

        if !(main.childWindows?.contains(p) == true) {
            main.addChildWindow(p, ordered: .above)
        }
        p.orderFront(nil)
    }

    public func updatePosition() {
        guard let p = panel, p.isVisible, let main = mainWindow, activeTab != .none else { return }
        let panelWidth: CGFloat = 380
        let mainFrame = main.frame
        let gap: CGFloat = 8
        let x = max(10, mainFrame.minX - panelWidth - gap)
        let y = mainFrame.minY
        let h = mainFrame.height
        p.setFrame(NSRect(x: x, y: y, width: panelWidth, height: h), display: true, animate: false)
    }
}

public struct SidePanelContainerView: View {
    @ObservedObject public var apiService: BurnerAPIService
    public let activeTab: SideDrawerTab
    public let onClose: () -> Void

    public init(apiService: BurnerAPIService, activeTab: SideDrawerTab, onClose: @escaping () -> Void) {
        self.apiService = apiService
        self.activeTab = activeTab
        self.onClose = onClose
    }

    public var body: some View {
        Group {
            if activeTab == .providers {
                ManageProvidersSheet(
                    apiService: apiService,
                    isPresented: Binding(
                        get: { true },
                        set: { if !$0 { onClose() } }
                    )
                )
            } else if activeTab == .optimizer {
                PromptOptimizerView(
                    apiService: apiService,
                    isPresented: Binding(
                        get: { true },
                        set: { if !$0 { onClose() } }
                    )
                )
            } else if activeTab == .handoff {
                HotSwapHandoffView(
                    apiService: apiService,
                    isPresented: Binding(
                        get: { true },
                        set: { if !$0 { onClose() } }
                    )
                )
            } else if activeTab == .trimmer {
                CodeTrimmerView(
                    apiService: apiService,
                    isPresented: Binding(
                        get: { true },
                        set: { if !$0 { onClose() } }
                    )
                )
            } else if activeTab == .planner {
                SprintPlannerView(
                    apiService: apiService,
                    isPresented: Binding(
                        get: { true },
                        set: { if !$0 { onClose() } }
                    )
                )
            }
        }
        .frame(width: 380)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.1)
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - Hot-Swap Handoff View (Phase 1)

public struct HotSwapHandoffView: View {
    @ObservedObject public var apiService: BurnerAPIService
    @Binding public var isPresented: Bool

    @State private var sourceProvider: ProviderID = .claude
    @State private var targetProvider: ProviderID = .cursor
    @State private var taskSummary: String = ""
    @State private var codeSnippet: String = ""
    @State private var unresolvedIssues: String = ""
    @State private var copied: Bool = false
    @State private var launched: Bool = false

    public init(apiService: BurnerAPIService, isPresented: Binding<Bool>) {
        self.apiService = apiService
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.orange)

                    Text("Hot-Swap Handoff Capsule")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.3))

            Divider().background(Color.white.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    // Subtitle & Explanation
                    Text("Hit a rate limit wall? Transfer your active coding session to a model with fresh quota without losing context or wasting tokens.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))

                    // Source & Target Transfer Bar
                    VStack(alignment: .leading, spacing: 6) {
                        Text("HOT-SWAP ROUTING")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.gray)

                        HStack(spacing: 8) {
                            // Source Provider Picker
                            VStack(alignment: .leading, spacing: 3) {
                                Text("FROM (Depleted)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.gray)
                                Menu {
                                    ForEach(ProviderID.allCases) { p in
                                        Button(p.displayName) {
                                            sourceProvider = p
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: sourceProvider.iconName)
                                            .foregroundColor(sourceProvider.brandColor)
                                        Text(sourceProvider.displayName)
                                            .foregroundColor(.white)
                                            .font(.system(size: 11, weight: .semibold))
                                        Spacer()
                                        if let q = apiService.providers.first(where: { $0.provider_id == sourceProvider }) {
                                            Text("\(Int(q.quota_remaining_percent))%")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(q.status.color)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(6)
                                }
                                .menuStyle(.borderlessButton)
                            }

                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.top, 14)

                            // Target Provider Picker
                            VStack(alignment: .leading, spacing: 3) {
                                Text("TO (Headroom)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.gray)
                                Menu {
                                    ForEach(ProviderID.allCases.filter { $0 != sourceProvider }) { p in
                                        Button(p.displayName) {
                                            targetProvider = p
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: targetProvider.iconName)
                                            .foregroundColor(targetProvider.brandColor)
                                        Text(targetProvider.displayName)
                                            .foregroundColor(.white)
                                            .font(.system(size: 11, weight: .semibold))
                                        Spacer()
                                        if let q = apiService.providers.first(where: { $0.provider_id == targetProvider }) {
                                            Text("\(Int(q.quota_remaining_percent))%")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(q.status.color)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(6)
                                }
                                .menuStyle(.borderlessButton)
                            }
                        }
                    }

                    // Demo Sample Shortcut Button
                    HStack {
                        Spacer()
                        Button(action: loadDemoSample) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                Text("Load Demo Sample")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }

                    // Task Input
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TASK GOAL & COMPLETED PROGRESS")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.gray)

                        TextEditor(text: $taskSummary)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .padding(6)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }

                    // Code Snippet Input
                    VStack(alignment: .leading, spacing: 5) {
                        Text("CURRENT CODE STATE / BUFFER (OPTIONAL)")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.gray)

                        TextEditor(text: $codeSnippet)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(6)
                            .frame(height: 60)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }

                    // Unresolved Issues Input
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ACTIVE ERRORS / IMMEDIATE NEXT ACTION")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.gray)

                        TextField("e.g. Signature verification failed on line 42", text: $unresolvedIssues)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }

                    // Generate Button
                    Button(action: {
                        Task {
                            await apiService.generateHandoffCapsule(
                                source: sourceProvider,
                                target: targetProvider,
                                taskSummary: taskSummary,
                                codeSnippet: codeSnippet.isEmpty ? nil : codeSnippet,
                                unresolvedIssues: unresolvedIssues.isEmpty ? nil : unresolvedIssues
                            )
                        }
                    }) {
                        HStack(spacing: 6) {
                            if apiService.isGeneratingCapsule {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                                Text("Synthesizing Capsule via Gemini...")
                                    .font(.system(size: 11.5, weight: .bold))
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                Text("Generate Handoff Capsule")
                                    .font(.system(size: 11.5, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(canGenerate ? Color.orange : Color.gray.opacity(0.3))
                        .foregroundColor(canGenerate ? .black : .white.opacity(0.5))
                        .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGenerate || apiService.isGeneratingCapsule)

                    // Capsule Output Section
                    if let capsule = apiService.activeHandoffCapsule {
                        VStack(alignment: .leading, spacing: 8) {
                            Divider().background(Color.white.opacity(0.1))

                            // Badges
                            HStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 9))
                                    Text("Saved ~\(capsule.estimated_token_savings) tokens")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)

                                HStack(spacing: 4) {
                                    Image(systemName: "shield.checkerboard")
                                        .font(.system(size: 9))
                                    Text("\(Int(capsule.target_quota_headroom_pct))% Headroom on \(capsule.target_provider.displayName)")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                            }

                            // Capsule Preview
                            ScrollView {
                                Text(capsule.capsule_prompt)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 100)
                            .background(Color.black.opacity(0.35))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )

                            // Actions
                            HStack(spacing: 8) {
                                Button(action: {
                                    copyToClipboard(capsule.capsule_prompt)
                                    copied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { copied = false }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                        Text(copied ? "Copied!" : "Copy Capsule")
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button(action: {
                                    copyToClipboard(capsule.capsule_prompt)
                                    Task {
                                        await apiService.launchTarget(providerId: capsule.target_provider, target: capsule.launch_target)
                                    }
                                    launched = true
                                    NotificationManager.shared.sendAlert(
                                        title: "Hot-Swap Handoff Ready",
                                        subtitle: "Swapped to \(capsule.target_provider.displayName)",
                                        body: "Capsule copied to clipboard! Paste directly into \(capsule.launch_target).",
                                        identifier: "burner-hotswap"
                                    )
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { launched = false }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: launched ? "checkmark.circle.fill" : "arrow.up.right.square.fill")
                                        Text(launched ? "Launched!" : "Copy & Launch \(capsule.launch_target)")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(Color.orange)
                                    .foregroundColor(.black)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.1)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
        .onAppear {
            initializeProviders()
        }
    }

    private func initializeProviders() {
        var foundSource: ProviderID? = nil
        for p in apiService.providers {
            if p.status == .critical || p.status == .exhausted {
                foundSource = p.provider_id
                break
            }
        }
        sourceProvider = foundSource ?? .claude

        var bestTarget: ProviderID = .cursor
        var bestHeadroom: Double = -1.0
        for p in apiService.providers {
            if p.provider_id != sourceProvider && p.quota_remaining_percent > bestHeadroom {
                bestHeadroom = p.quota_remaining_percent
                bestTarget = p.provider_id
            }
        }
        targetProvider = bestTarget
    }

    private var canGenerate: Bool {
        !taskSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func loadDemoSample() {
        taskSummary = "Refactor AuthSessionManager to support automatic JWT refresh cookies and Keychain token persistence."
        codeSnippet = """
class AuthSessionManager:
    def __init__(self, api_client):
        self.client = api_client
        self.access_token = None

    def refresh_session(self):
        # TODO: Add Keychain lookup and refresh rotation
        pass
"""
        unresolvedIssues = "Keychain access group entitlement error on macOS Sequoia; refresh token returns 401 on second rotation."
    }
}

// MARK: - Context-Compressing Code Trimmer View (Phase 2)

public struct CodeTrimmerView: View {
    @ObservedObject public var apiService: BurnerAPIService
    @Binding public var isPresented: Bool

    @State private var codeInput: String = ""
    @State private var taskFocus: String = ""
    @State private var selectedMode: CompressionMode = .balanced
    @State private var copied: Bool = false

    public init(apiService: BurnerAPIService, isPresented: Binding<Bool>) {
        self.apiService = apiService
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            Divider().background(Color.white.opacity(0.1))

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    // Subtitle / value proposition banner
                    bannerView

                    // Compression Mode Selector
                    modeSelectorSection

                    // Task Focus (Optional)
                    taskFocusSection

                    // Code Input Area
                    codeInputSection

                    // Trim Action Button
                    actionButton

                    // Result View
                    if let result = apiService.activeCodeTrimResult {
                        resultSection(result: result)
                    }
                }
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.1)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "scissors")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.6))

                Text("Context Code Trimmer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var bannerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.shield.fill")
                .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.6))
                .font(.system(size: 13))

            Text("Prunes boilerplate & AST skeletons to save 60–80% prompt tokens before sending to LLMs.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .background(Color(red: 0.12, green: 0.25, blue: 0.18).opacity(0.4))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.2, green: 0.85, blue: 0.6).opacity(0.3), lineWidth: 0.8)
        )
    }

    private var modeSelectorSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COMPRESSION MODE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                ForEach(CompressionMode.allCases) { mode in
                    let isSelected = selectedMode == mode
                    Button(action: { selectedMode = mode }) {
                        Text(mode.title)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(
                                isSelected
                                    ? Color(red: 0.2, green: 0.85, blue: 0.6)
                                    : Color.white.opacity(0.06)
                            )
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var taskFocusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TASK FOCUS (OPTIONAL)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)

            TextField("e.g. fix refresh token rotation handling", text: $taskFocus)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .padding(7)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private var codeInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CODE TO COMPRESS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: loadDemoCode) {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                        Text("Load Sample")
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.6))
                }
                .buttonStyle(.plain)
            }

            TextEditor(text: $codeInput)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .frame(height: 120)
                .padding(6)
                .background(Color.black.opacity(0.4))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    private var actionButton: some View {
        Button(action: triggerTrim) {
            HStack(spacing: 6) {
                if apiService.isTrimmingCode {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "scissors")
                        .font(.system(size: 11, weight: .bold))
                }

                Text(apiService.isTrimmingCode ? "Compressing AST..." : "Compress & Trim Code")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                canTrim
                    ? Color(red: 0.2, green: 0.85, blue: 0.6)
                    : Color.white.opacity(0.2)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(!canTrim || apiService.isTrimmingCode)
    }

    private func resultSection(result: CodeTrimResponsePayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("COMPRESSION RESULTS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Engine: \(result.engine)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            // Metric card
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Token Usage")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text("\(result.original_token_count)")
                            .strikethrough()
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("\(result.trimmed_token_count)")
                            .foregroundColor(.white)
                            .bold()
                    }
                    .font(.system(size: 11, design: .monospaced))
                }

                Spacer()

                // Badge for savings
                Text(String(format: "-%.0f%%", result.compression_ratio_pct))
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.2, green: 0.85, blue: 0.6))
                    .cornerRadius(4)

                // Safe prompts badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Quota Gained")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("+\(result.safe_prompts_gained) Prompts")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.6))
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))

            Text(result.explanation)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // Trimmed code preview
            ScrollView(.vertical, showsIndicators: true) {
                Text(result.trimmed_code)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(red: 0.75, green: 0.95, blue: 0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 120)
            .background(Color.black.opacity(0.5))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.2, green: 0.85, blue: 0.6).opacity(0.3), lineWidth: 1))

            // Action row
            HStack(spacing: 8) {
                Button(action: {
                    copyToClipboard(result.trimmed_code)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        copied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy Trimmed Code")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: {
                    apiService.activeCodeTrimResult = nil
                }) {
                    Text("Clear")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var canTrim: Bool {
        !codeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func triggerTrim() {
        Task {
            await apiService.trimCode(
                code: codeInput,
                mode: selectedMode,
                taskFocus: taskFocus.isEmpty ? nil : taskFocus,
                language: "python"
            )
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func loadDemoCode() {
        taskFocus = "Fix refresh token rotation handling"
        codeInput = """
class TokenManager:
    \"\"\"
    A comprehensive token management and session orchestration class that
    handles OAuth2 tokens, refresh cycles, signature verification, and logging.
    \"\"\"
    def __init__(self, client_id: str, client_secret: str):
        # Initialize internal state and caching variables
        self.client_id = client_id
        self.client_secret = client_secret
        self._cache = {}
        self.logger = logging.getLogger("TokenManager")
        self.logger.setLevel(logging.DEBUG)
        self.retry_count = 0

    def calculate_checksum(self, data: bytes) -> str:
        # Standard SHA256 checksum helper
        import hashlib
        return hashlib.sha256(data).hexdigest()

    def validate_client_credentials(self) -> bool:
        if not self.client_id or not self.client_secret:
            return False
        return len(self.client_secret) >= 16

    def refresh_token(self, old_refresh_token: str) -> dict:
        \"\"\"Executes token refresh against OAuth server\"\"\"
        if not old_refresh_token:
            raise ValueError("Token is missing")
        # Critical issue: refresh token rotation raises 401 when token re-used
        payload = {"refresh_token": old_refresh_token, "client_id": self.client_id}
        response = requests.post("https://api.example.com/oauth/token", json=payload)
        if response.status_code != 200:
            raise RuntimeError(f"Refresh failed: {response.text}")
        return response.json()

    def purge_expired_sessions(self):
        # Routine housekeeping routine run periodically
        now = time.time()
        for k in list(self._cache.keys()):
            if self._cache[k].get("expires_at", 0) < now:
                del self._cache[k]
"""
    }
}

// MARK: - Autonomous Sprint Token Planner View (Phase 3)

public struct SprintPlannerView: View {
    @ObservedObject public var apiService: BurnerAPIService
    @Binding public var isPresented: Bool

    @State private var taskDescription: String = ""
    @State private var copiedStageId: Int? = nil

    public init(apiService: BurnerAPIService, isPresented: Binding<Bool>) {
        self.apiService = apiService
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            Divider().background(Color.white.opacity(0.1))

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    // Explainer Banner
                    bannerView

                    // Objective Input Section
                    objectiveSection

                    // Action Button
                    actionButton

                    // Plan Results Deck
                    if let plan = apiService.activeSprintPlan {
                        planResultDeck(plan: plan)
                    }
                }
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.1)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.95))

                Text("Sprint Token Planner")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var bannerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.95))
                .font(.system(size: 13))

            Text("Decomposes features across 3 models (Codex ➔ Claude ➔ Cursor) to preserve scarce Sonnet quota.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .background(Color(red: 0.2, green: 0.14, blue: 0.32).opacity(0.4))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.75, green: 0.55, blue: 0.95).opacity(0.3), lineWidth: 0.8)
        )
    }

    private var objectiveSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("FEATURE / SPRINT OBJECTIVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: loadDemoSample) {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                        Text("Load Sample")
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.95))
                }
                .buttonStyle(.plain)
            }

            TextEditor(text: $taskDescription)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.9))
                .frame(height: 75)
                .padding(6)
                .background(Color.black.opacity(0.4))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    private var actionButton: some View {
        Button(action: triggerPlan) {
            HStack(spacing: 6) {
                if apiService.isPlanningSprint {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 11, weight: .bold))
                }

                Text(apiService.isPlanningSprint ? "Decomposing Architecture..." : "Generate Multi-Model Plan")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                canPlan
                    ? Color(red: 0.75, green: 0.55, blue: 0.95)
                    : Color.white.opacity(0.2)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(!canPlan || apiService.isPlanningSprint)
    }

    private func planResultDeck(plan: SprintPlanResponsePayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Budget Metrics Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SPRINT BUDGET SAVINGS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Engine: \(plan.engine)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monolith Burn Avoided")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("~\(plan.tokens_saved_vs_monolith) Tok")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.95))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("High-Reasoning Preserved")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("+\(plan.claude_prompts_preserved) Claude Prompts")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))

            Text(plan.explanation)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            // Stages list
            VStack(spacing: 10) {
                ForEach(plan.stages) { stage in
                    stageCard(stage: stage)
                }
            }

            // Clear Button
            Button(action: {
                apiService.activeSprintPlan = nil
            }) {
                Text("Clear Sprint Plan")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private func stageCard(stage: SprintStagePayload) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Stage header
            HStack(spacing: 6) {
                Text("STAGE \(stage.stage_number)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(stageColor(stage.stage_number))
                    .cornerRadius(4)

                Text(stage.stage_name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Text("~\(stage.estimated_tokens) tok")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Target model badge
            HStack(spacing: 4) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text("Assigned:")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(stage.suggested_model)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(stageColor(stage.stage_number))
            }

            Text(stage.rationale)
                .font(.system(size: 9.5))
                .foregroundColor(.white.opacity(0.7))

            // Monospaced prompt template
            ScrollView(.vertical, showsIndicators: true) {
                Text(stage.prompt_template)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }
            .frame(height: 55)
            .background(Color.black.opacity(0.5))
            .cornerRadius(5)

            // Action row
            HStack(spacing: 6) {
                let isCopied = copiedStageId == stage.stage_number
                Button(action: {
                    copyToClipboard(stage.prompt_template)
                    copiedStageId = stage.stage_number
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if copiedStageId == stage.stage_number {
                            copiedStageId = nil
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied!" : "Copy Stage \(stage.stage_number) Prompt")
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button(action: {
                    let targetName = stageLaunchTarget(stage.assigned_provider)
                    Task {
                        await apiService.launchTarget(providerId: stage.assigned_provider, target: targetName)
                    }
                }) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Launch \(stage.suggested_model)")
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(stageColor(stage.stage_number).opacity(0.3), lineWidth: 1)
        )
    }

    private func stageColor(_ number: Int) -> Color {
        switch number {
        case 1: return Color.cyan
        case 2: return Color.orange
        case 3: return Color.green
        default: return Color.purple
        }
    }

    private func stageLaunchTarget(_ provider: ProviderID) -> String {
        switch provider {
        case .claude: return "Claude"
        case .cursor: return "Cursor"
        case .codex: return "ChatGPT"
        case .copilot: return "Visual Studio Code"
        case .gemini: return "https://aistudio.google.com"
        }
    }

    private var canPlan: Bool {
        !taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func triggerPlan() {
        Task {
            await apiService.planSprint(taskDescription: taskDescription)
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func loadDemoSample() {
        taskDescription = "Build Stripe Checkout webhook endpoint with database idempotency, customer subscription updates, and unit tests."
    }
}

