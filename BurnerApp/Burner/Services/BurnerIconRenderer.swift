import AppKit
import SwiftUI

public class BurnerIconRenderer {
    public static func createDockIcon() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()

        // macOS Squircle Bounds
        let squircleRect = NSRect(x: 40, y: 40, width: 432, height: 432)
        let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: 96, yRadius: 96)

        // 1. Dark Gradient Background
        let bgGradient = NSGradient(
            starting: NSColor(red: 0.13, green: 0.09, blue: 0.18, alpha: 1.0),
            ending: NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1.0)
        )
        bgGradient?.draw(in: squirclePath, angle: -45)

        // 2. Subtle Radial Glow in Center
        let glowRect = NSRect(x: 106, y: 106, width: 300, height: 300)
        let glowPath = NSBezierPath(ovalIn: glowRect)
        let glowGradient = NSGradient(
            starting: NSColor(red: 1.0, green: 0.45, blue: 0.1, alpha: 0.35),
            ending: NSColor(red: 1.0, green: 0.2, blue: 0.0, alpha: 0.0)
        )
        glowGradient?.draw(in: glowPath, relativeCenterPosition: .zero)

        // 3. Border Stroke
        NSColor(white: 1.0, alpha: 0.15).setStroke()
        squirclePath.lineWidth = 3.0
        squirclePath.stroke()

        // 4. Flame Symbol
        let config = NSImage.SymbolConfiguration(pointSize: 220, weight: .bold)
            .applying(.init(paletteColors: [
                NSColor(red: 1.0, green: 0.6, blue: 0.15, alpha: 1.0),
                NSColor(red: 1.0, green: 0.25, blue: 0.1, alpha: 1.0)
            ]))

        if let flame = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let flameRect = NSRect(x: 136, y: 116, width: 240, height: 270)
            flame.draw(in: flameRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        image.unlockFocus()
        return image
    }
}
