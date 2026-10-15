//
//  FocusBorder.swift
//  Amethyst
//
//  A border around the focused window, drawn by a click-through overlay just outside the window's frame.
//

import Cocoa
import Darwin
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

/// Private SkyLight calls for following a window as the window server moves it, looked up at runtime: if a macOS update removes
/// them, the border falls back to Accessibility events. Signatures as used by window tools such as JankyBorders and yabai.
private enum WindowServer {
    typealias NotifyHandler = @convention(c) (UInt32, UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Void

    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias RegisterNotifyProc = @convention(c) (NotifyHandler, UInt32, UnsafeMutableRawPointer?) -> Int32
    private typealias RequestNotificationsForWindows = @convention(c) (Int32, UnsafeMutablePointer<UInt32>, Int32) -> Int32
    private typealias GetWindowBounds = @convention(c) (Int32, UInt32, UnsafeMutablePointer<CGRect>) -> Int32

    static let windowMoved: UInt32 = 806
    static let windowResized: UInt32 = 807

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func function<T>(_ name: String, _ type: T.Type) -> T? {
        guard let skyLight, let pointer = dlsym(skyLight, name) else {
            return nil
        }
        return unsafeBitCast(pointer, to: type)
    }

    private static let mainConnectionID = function("SLSMainConnectionID", MainConnectionID.self)
    private static let registerNotifyProc = function("SLSRegisterNotifyProc", RegisterNotifyProc.self)
    private static let requestNotificationsForWindows = function("SLSRequestNotificationsForWindows", RequestNotificationsForWindows.self)
    private static let getWindowBounds = function("SLSGetWindowBounds", GetWindowBounds.self)

    /// Registers the handler for the events; false if any call is missing or fails.
    static func register(_ handler: NotifyHandler, for events: [UInt32]) -> Bool {
        guard let registerNotifyProc, mainConnectionID != nil, requestNotificationsForWindows != nil, getWindowBounds != nil else {
            return false
        }
        return events.allSatisfy { registerNotifyProc(handler, $0, nil) == 0 }
    }

    /// Asks for the registered events of this window (replacing the window asked for before).
    static func requestNotifications(for windowID: CGWindowID) {
        guard let mainConnectionID, let requestNotificationsForWindows else {
            return
        }
        var windowIDs = [UInt32(windowID)]
        _ = requestNotificationsForWindows(mainConnectionID(), &windowIDs, 1)
    }

    /// The window's frame, top-left origin like Accessibility frames.
    static func bounds(of windowID: CGWindowID) -> CGRect? {
        guard let mainConnectionID, let getWindowBounds else {
            return nil
        }
        var bounds = CGRect.zero
        return getWindowBounds(mainConnectionID(), UInt32(windowID), &bounds) == 0 ? bounds : nil
    }
}

/// The overlay that draws the focus border. Main thread only.
final class FocusBorder {
    private lazy var panel = FocusBorderPanel()
    private var appearance: FocusBorderAppearance?
    private var windowFrame: CGRect?

    /// The window the border is around, if it's showing.
    private(set) var currentWindowID: CGWindowID?

    /// Whether the border follows the window-server's own move and resize events, which come every frame, also mid-drag.
    /// Without them it follows Accessibility events, which come late and in bursts.
    private var followsWindowServer = false
    /// Accessibility frames lag behind the window server's; while its events keep coming, they'd pull the border back.
    private var lastWindowServerEvent: Date?

    /// Receives the window-server events; a C callback can't capture, so it finds the border here.
    private static weak var followed: FocusBorder?

    private static let windowServerHandler: WindowServer.NotifyHandler = { _, data, length, _ in
        guard let data, length >= MemoryLayout<UInt32>.size else {
            return
        }

        let windowID = data.loadUnaligned(as: UInt32.self)
        let follow: () -> Void = { FocusBorder.followed?.windowServerDidChange(windowID) }
        if Thread.isMainThread {
            follow()
        } else {
            DispatchQueue.main.async(execute: follow)
        }
    }

    init() {
        followsWindowServer = WindowServer.register(FocusBorder.windowServerHandler, for: [WindowServer.windowMoved, WindowServer.windowResized])
        FocusBorder.followed = self
        if !followsWindowServer {
            log.warning("Focus border: window-server events unavailable, following Accessibility events")
        }
    }

    func show(around windowFrame: CGRect, above windowID: CGWindowID, appearance: FocusBorderAppearance) {
        self.appearance = appearance
        if followsWindowServer && windowID != currentWindowID {
            WindowServer.requestNotifications(for: windowID)
            lastWindowServerEvent = nil
        }
        currentWindowID = windowID
        move(to: windowFrame, force: true)
        panel.orderFrontRegardless()
    }

    /// Follows the window on its Accessibility moved and resized events, unless the window server is already reporting them.
    func move(to windowFrame: CGRect) {
        if let lastWindowServerEvent, Date().timeIntervalSince(lastWindowServerEvent) < 0.5 {
            return
        }
        move(to: windowFrame, force: false)
    }

    func hide() {
        currentWindowID = nil
        windowFrame = nil
        panel.orderOut(nil)
    }

    private func windowServerDidChange(_ windowID: CGWindowID) {
        guard windowID == currentWindowID, let appearance, let bounds = WindowServer.bounds(of: windowID) else {
            return
        }

        lastWindowServerEvent = Date()
        guard let windowFrame, bounds.size == windowFrame.size else {
            // A resize redraws the ring.
            move(to: bounds, force: false)
            return
        }

        // A move only shifts the overlay, without drawing.
        self.windowFrame = bounds
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        panel.setFrameOrigin(appearance.overlayFrame(forWindowFrame: bounds, primaryScreenHeight: primaryScreenHeight).origin)
    }

    private func move(to windowFrame: CGRect, force: Bool) {
        guard let appearance, currentWindowID != nil, force || windowFrame != self.windowFrame else {
            return
        }

        self.windowFrame = windowFrame
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
