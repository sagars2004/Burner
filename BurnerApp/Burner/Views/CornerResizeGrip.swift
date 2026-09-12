import SwiftUI
import AppKit
import Combine

public class WindowResizeManager: NSObject, ObservableObject {
    public static let shared = WindowResizeManager()

    @Published public var currentWidth: CGFloat = 480
    @Published public var currentHeight: CGFloat = 640

    public weak var window: NSWindow?
    public var isDrawerOpen: Bool = false
    public var isUpdatingFrame: Bool = false
    private var hasSetInitialFrame: Bool = false

    override public init() {
        super.init()
        let savedW = UserDefaults.standard.double(forKey: "burnerPanelWidth")
        let savedH = UserDefaults.standard.double(forKey: "burnerPanelHeight")
        if savedW >= 460 { self.currentWidth = CGFloat(savedW) } else { self.currentWidth = 480 }
        if savedH >= 500 { self.currentHeight = CGFloat(savedH) } else { self.currentHeight = 640 }
    }

    public func attach(window: NSWindow) {
        if self.window === window { return }
        self.window = window

        // Make window background transparent so there's no ghost border outside the card
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true

        // Set initial frame from saved preferences
        if !hasSetInitialFrame {
            hasSetInitialFrame = true
            let targetW = currentWidth
            let targetH = currentHeight

            let currentFrame = window.frame
            let topY = currentFrame.maxY
            let newY = topY - targetH
            let initialFrame = NSRect(x: currentFrame.origin.x, y: newY, width: targetW, height: targetH)
            isUpdatingFrame = true
            window.setFrame(initialFrame, display: true, animate: false)
            isUpdatingFrame = false
        }
    }
}

public struct CornerResizeGrip: View {
    public init() {}

    public var body: some View {
        CornerResizeGripRepresentable()
            .frame(width: 24, height: 24)
            .help("Drag to resize panel")
    }
}

public struct CornerResizeGripRepresentable: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> ResizeGripNSView {
        return ResizeGripNSView(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
    }

    public func updateNSView(_ nsView: ResizeGripNSView, context: Context) {
        nsView.needsDisplay = true
    }
}

public class ResizeGripNSView: NSView {
    private var isHovered: Bool = false
    private var isDragging: Bool = false
    private var dragStartMouse: NSPoint = .zero
    private var dragStartWidth: CGFloat = 480
    private var dragStartHeight: CGFloat = 640
    private var dragStartFrame: NSRect = .zero
    private var trackingArea: NSTrackingArea?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .cursorUpdate]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    public override func cursorUpdate(with event: NSEvent) {
        setResizeCursor()
    }

    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
        setResizeCursor()
        needsDisplay = true
    }

    public override func mouseExited(with event: NSEvent) {
        isHovered = false
        if !isDragging {
            NSCursor.arrow.set()
        }
        needsDisplay = true
    }

    private func setResizeCursor() {
        let selector = NSSelectorFromString("_windowResizeNorthWestSouthEastCursor")
        if NSCursor.responds(to: selector),
           let cursor = NSCursor.perform(selector)?.takeUnretainedValue() as? NSCursor {
            cursor.set()
        } else {
            NSCursor.crosshair.set()
        }
    }

    public override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        isDragging = true
        dragStartMouse = NSEvent.mouseLocation
        dragStartWidth = WindowResizeManager.shared.currentWidth
        dragStartHeight = WindowResizeManager.shared.currentHeight
        dragStartFrame = window.frame
        setResizeCursor()
        needsDisplay = true
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDragging, let window = self.window, dragStartFrame != .zero else { return }

        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - dragStartMouse.x
        let deltaY = dragStartMouse.y - currentMouse.y

        let minW: CGFloat = 460
        let maxW: CGFloat = 1100
        let minH: CGFloat = 500
        let maxH: CGFloat = 1200

        let newW = max(minW, min(maxW, dragStartWidth + deltaX))
        let newH = max(minH, min(maxH, dragStartHeight + deltaY))

        // 1. Update SwiftUI state so content stretches to 100% of the new width/height
        WindowResizeManager.shared.currentWidth = newW
        WindowResizeManager.shared.currentHeight = newH

        // 2. Update the AppKit window frame to match in lockstep
        let topY = dragStartFrame.maxY
        let newY = topY - newH
        let newFrame = NSRect(x: dragStartFrame.origin.x, y: newY, width: newW, height: newH)

        WindowResizeManager.shared.isUpdatingFrame = true
        window.setFrame(newFrame, display: true, animate: false)
        WindowResizeManager.shared.isUpdatingFrame = false

        // 3. Keep auxiliary side panel attached to left of main window if open
        SidePanelManager.shared.updatePosition()
    }

    public override func mouseUp(with event: NSEvent) {
        isDragging = false
        let finalW = WindowResizeManager.shared.currentWidth
        let finalH = WindowResizeManager.shared.currentHeight
        UserDefaults.standard.set(Double(finalW), forKey: "burnerPanelWidth")
        UserDefaults.standard.set(Double(finalH), forKey: "burnerPanelHeight")
        if !isHovered {
            NSCursor.arrow.set()
        }
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()

        let strokeColor: NSColor
        if isDragging {
            strokeColor = NSColor.cyan
        } else if isHovered {
            strokeColor = NSColor.white.withAlphaComponent(0.9)
        } else {
            strokeColor = NSColor.white.withAlphaComponent(0.35)
        }

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(1.5)
        context.setLineCap(.round)

        let w = bounds.width

        // 3 diagonal grip marks
        // Short line near corner
        context.move(to: CGPoint(x: w - 5, y: 13))
        context.addLine(to: CGPoint(x: w - 13, y: 5))

        // Middle line
        context.move(to: CGPoint(x: w - 5, y: 9))
        context.addLine(to: CGPoint(x: w - 9, y: 5))

        // Outer line
        context.move(to: CGPoint(x: w - 5, y: 17))
        context.addLine(to: CGPoint(x: w - 17, y: 5))

        context.strokePath()
        context.restoreGState()
    }
}

public struct WindowAccessor: NSViewRepresentable {
    public let callback: (NSWindow) -> Void

    public init(callback: @escaping (NSWindow) -> Void) {
        self.callback = callback
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                callback(window)
            }
        }
    }
}
