//
//  FocusBorder.swift
//  Amethyst
//
//  A border around the focused window, drawn by a click-through overlay just outside the window's frame.
//

import Cocoa
import QuartzCore

enum FocusBorderStyle: String, CaseIterable {
    /// A thin ring with a soft glow, like the macOS keyboard focus ring.
    case glow
    /// A plain ring of `focus-border-width`.
    case solid
    /// A ring running from the first to the second `focus-border-gradient` colour.
    case gradient

    var next: FocusBorderStyle {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// A colour from the configuration: the system accent colour, or `#RRGGBB` / `#AARRGGBB`.
enum FocusBorderColor: Equatable {
    case accent
    case rgba(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)

    init?(_ string: String) {
        let text = string.trimmingCharacters(in: .whitespaces).lowercased()
        if text == "accent" {
            self = .accent
            return
        }

        let hex = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard hex.count == 6 || hex.count == 8, hex.allSatisfy(\.isHexDigit), let value = UInt32(hex, radix: 16) else {
            return nil
        }

        let argb = hex.count == 6 ? 0xFF00_0000 | value : value
        func channel(_ shift: UInt32) -> CGFloat {
            return CGFloat((argb >> shift) & 0xFF) / 255
        }
        self = .rgba(red: channel(16), green: channel(8), blue: channel(0), alpha: channel(24))
    }

    /// Read at every use, so a new accent colour in System Settings applies on the next update.
    var cgColor: CGColor {
        switch self {
        case .accent:
            return NSColor.controlAccentColor.cgColor
        case let .rgba(red, green, blue, alpha):
            return CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        }
    }
}

struct FocusBorderAppearance: Equatable {
    static let glowRingWidth: CGFloat = 1.5
    /// Ametrine purple to gold, like the icon.
    static let defaultGradient: [FocusBorderColor] = ["#9B5DE5", "#F4B942"].compactMap(FocusBorderColor.init)

    var style: FocusBorderStyle
    var width: CGFloat
    var radius: CGFloat
    var color: FocusBorderColor
    var gradient: [FocusBorderColor]

    /// How far the overlay reaches beyond the window frame on each side.
    var reach: CGFloat {
        switch style {
        case .glow:
            return Self.glowRingWidth + 2 * width
        case .solid, .gradient:
            return width
        }
    }

    /// The ring's line width; the ring lies just outside the window frame.
    var ringWidth: CGFloat {
        return style == .glow ? Self.glowRingWidth : width
    }

    /// The overlay's frame in Cocoa coordinates (origin bottom left) for a window frame in screen coordinates (origin top left).
    func overlayFrame(forWindowFrame windowFrame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        let flipped = CGRect(x: windowFrame.minX, y: primaryScreenHeight - windowFrame.maxY, width: windowFrame.width, height: windowFrame.height)
        return flipped.insetBy(dx: -reach, dy: -reach)
    }
}

final class FocusBorderPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        // One level above app windows: apps raise their own window whenever they like (a click, CotEditor while selecting text),
        // which covered a border kept just above the window. The focused window is the frontmost app window, so nothing else
        // shows under the ring; menus and floating panels (Raycast, …) sit higher and still cover it.
        level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)

        let view = NSView()
        view.wantsLayer = true
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// AppKit pushes windows out from under the menu bar; the border must sit exactly around its window.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

/// The overlay that draws the focus border. Main thread only.
final class FocusBorder {
    private lazy var panel = FocusBorderPanel()
    private var appearance: FocusBorderAppearance?
    private var windowFrame: CGRect?

    /// The window the border is around, if it's showing.
    private(set) var currentWindowID: CGWindowID?

    /// Moved events arrive in bursts while a window is dragged, so the border would trail it. It's hidden from the first drag event
    /// that starts on the window or its edge (a move, a resize, also a text selection) until the mouse is released.
    private var isHiddenForDrag = false
    private var mouseDownLocation: CGPoint?
    private var mouseMonitor: Any?

    init() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            let type = event.type
            let location = NSEvent.mouseLocation
            DispatchQueue.main.async {
                self?.handleMouse(type, at: location)
            }
        }
    }

    deinit {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
    }

    /// - Parameter location: In screen coordinates, origin bottom left (`NSEvent.mouseLocation`).
    private func handleMouse(_ type: NSEvent.EventType, at location: CGPoint) {
        switch type {
        case .leftMouseDown:
            mouseDownLocation = location
        case .leftMouseDragged:
            // Checked now, not on mouse-down: a click on another window moves the border there first.
            if let mouseDownLocation, !isHiddenForDrag, isOnWindow(mouseDownLocation) {
                isHiddenForDrag = true
                panel.orderOut(nil)
            }
        case .leftMouseUp:
            mouseDownLocation = nil
            endDrag()
        default:
            break
        }
    }

    /// Whether a point is on the bordered window or within a few points of its edge, where a resize starts.
    private func isOnWindow(_ location: CGPoint) -> Bool {
        guard let windowFrame, currentWindowID != nil else {
            return false
        }

        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let flipped = CGRect(x: windowFrame.minX, y: primaryScreenHeight - windowFrame.maxY, width: windowFrame.width, height: windowFrame.height)
        return flipped.insetBy(dx: -6, dy: -6).contains(location)
    }

    func show(around windowFrame: CGRect, above windowID: CGWindowID, appearance: FocusBorderAppearance) {
        self.appearance = appearance
        currentWindowID = windowID
        move(to: windowFrame, force: true)
        if !isHiddenForDrag {
            panel.orderFrontRegardless()
        }
    }

    /// Follows the window while it moves or resizes.
    func move(to windowFrame: CGRect) {
        move(to: windowFrame, force: false)
    }

    func hide() {
        currentWindowID = nil
        windowFrame = nil
        isHiddenForDrag = false
        panel.orderOut(nil)
    }

    private func endDrag() {
        guard isHiddenForDrag else {
            return
        }

        isHiddenForDrag = false
        guard let windowFrame, currentWindowID != nil else {
            return
        }

        move(to: windowFrame, force: true)
        panel.orderFrontRegardless()
    }

    private func move(to windowFrame: CGRect, force: Bool) {
        guard let appearance, currentWindowID != nil, force || windowFrame != self.windowFrame else {
            return
        }

        self.windowFrame = windowFrame

        // The window moves under the mouse: a drag by its title bar or edge.
        if !force && NSEvent.pressedMouseButtons & 1 != 0 {
            isHiddenForDrag = true
            panel.orderOut(nil)
        }
        if isHiddenForDrag {
            return
        }

        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        panel.setFrame(appearance.overlayFrame(forWindowFrame: windowFrame, primaryScreenHeight: primaryScreenHeight), display: false)
        draw(appearance)
    }

    private func draw(_ appearance: FocusBorderAppearance) {
        guard let rootLayer = panel.contentView?.layer else {
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let bounds = CGRect(origin: .zero, size: panel.frame.size)
        let windowRect = bounds.insetBy(dx: appearance.reach, dy: appearance.reach)
        let ringRect = windowRect.insetBy(dx: -appearance.ringWidth / 2, dy: -appearance.ringWidth / 2)
        let ringRadius = appearance.radius + appearance.ringWidth / 2
        let ringPath = CGPath(roundedRect: ringRect, cornerWidth: ringRadius, cornerHeight: ringRadius, transform: nil)

        let ring = CAShapeLayer()
        ring.frame = bounds
        ring.path = ringPath
        ring.fillColor = nil
        ring.lineWidth = appearance.ringWidth

        let content: CALayer
        switch appearance.style {
        case .solid:
            ring.strokeColor = appearance.color.cgColor
            content = ring
        case .glow:
            let color = appearance.color.cgColor
            ring.strokeColor = color
            ring.shadowColor = color
            ring.shadowOpacity = 0.9
            ring.shadowRadius = appearance.width
            ring.shadowOffset = .zero
            content = ring
        case .gradient:
            ring.strokeColor = CGColor(gray: 0, alpha: 1)
            let gradient = CAGradientLayer()
            gradient.frame = bounds
            gradient.colors = appearance.gradient.map(\.cgColor)
            gradient.startPoint = CGPoint(x: 0, y: 1)
            gradient.endPoint = CGPoint(x: 1, y: 0)
            gradient.mask = ring
            content = gradient
        }

        // Nothing is drawn over the window itself, not even the inner half of the glow.
        let outside = CAShapeLayer()
        outside.frame = bounds
        let outsidePath = CGMutablePath()
        outsidePath.addRect(bounds)
        outsidePath.addPath(CGPath(roundedRect: windowRect, cornerWidth: appearance.radius, cornerHeight: appearance.radius, transform: nil))
        outside.path = outsidePath
        outside.fillRule = .evenOdd

        let container = CALayer()
        container.frame = bounds
        container.mask = outside
        container.addSublayer(content)

        rootLayer.sublayers = [container]
    }
}
