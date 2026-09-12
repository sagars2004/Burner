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
