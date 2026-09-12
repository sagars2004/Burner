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

