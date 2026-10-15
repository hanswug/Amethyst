//
//  WindowServerBorder.swift
//  Amethyst
//
//  The focus border as a window of its own in the window server, drawn with Core Graphics and moved in window-server
//  transactions off the main thread, so it keeps up with a window being dragged or resized. Uses private SkyLight calls, the
//  same ones window tools such as JankyBorders and yabai rely on, looked up at runtime: without them FocusBorder falls back to
//  an AppKit panel.
//

import Cocoa
import Darwin

/// Private SkyLight and CoreGraphics calls, resolved once. `isAvailable` only if every one of them was found.
enum SkyLight {
    typealias NotifyHandler = @convention(c) (UInt32, UnsafeMutableRawPointer?, Int, UnsafeMutableRawPointer?) -> Void

    static let windowMoved: UInt32 = 806
    static let windowResized: UInt32 = 807

    private static let handle: UnsafeMutableRawPointer? = {
        _ = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        return UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT: every loaded image
    }()

    private static func function<T>(_ name: String, _ type: T.Type) -> T? {
        guard let pointer = dlsym(handle, name) else {
            log.warning("SkyLight: \(name) not found")
            return nil
        }
        return unsafeBitCast(pointer, to: type)
    }

    static let mainConnectionID = function("SLSMainConnectionID", (@convention(c) () -> Int32).self)
    static let newConnection = function("SLSNewConnection", (@convention(c) (Int32, UnsafeMutablePointer<Int32>) -> Int32).self)
    static let registerNotifyProc = function("SLSRegisterNotifyProc", (@convention(c) (NotifyHandler, UInt32, UnsafeMutableRawPointer?) -> Int32).self)
    static let requestNotificationsForWindows = function(
        "SLSRequestNotificationsForWindows", (@convention(c) (Int32, UnsafeMutablePointer<UInt32>, Int32) -> Int32).self
    )
    static let getWindowBounds = function("SLSGetWindowBounds", (@convention(c) (Int32, UInt32, UnsafeMutablePointer<CGRect>) -> Int32).self)
    static let newRegionWithRect = function(
        "CGSNewRegionWithRect", (@convention(c) (UnsafePointer<CGRect>, UnsafeMutablePointer<Unmanaged<CFTypeRef>?>) -> Int32).self
    )
    static let newWindow = function(
        "SLSNewWindow", (@convention(c) (Int32, Int32, Float, Float, CFTypeRef, UnsafeMutablePointer<UInt32>) -> Int32).self
    )
    static let releaseWindow = function("SLSReleaseWindow", (@convention(c) (Int32, UInt32) -> Int32).self)
    static let setWindowResolution = function("SLSSetWindowResolution", (@convention(c) (Int32, UInt32, Double) -> Int32).self)
    static let setWindowOpacity = function("SLSSetWindowOpacity", (@convention(c) (Int32, UInt32, Bool) -> Int32).self)
    static let setWindowTags = function("SLSSetWindowTags", (@convention(c) (Int32, UInt32, UnsafeMutablePointer<UInt64>, Int32) -> Int32).self)
    static let setShadowProperties = function("SLSWindowSetShadowProperties", (@convention(c) (UInt32, CFDictionary) -> Int32).self)
    static let setWindowShape = function("SLSSetWindowShape", (@convention(c) (Int32, UInt32, Float, Float, CFTypeRef) -> Int32).self)
    static let windowContextCreate = function("SLWindowContextCreate", (@convention(c) (Int32, UInt32, CFDictionary?) -> Unmanaged<CGContext>?).self)
    static let flushWindowContentRegion = function("SLSFlushWindowContentRegion", (@convention(c) (Int32, UInt32, UnsafeMutableRawPointer?) -> Int32).self)
    static let freezeWindow = function("SLSWindowFreezeWithOptions", (@convention(c) (Int32, UInt32, CFTypeRef?) -> Int32).self)
    static let thawWindow = function("SLSWindowThaw", (@convention(c) (Int32, UInt32) -> Int32).self)
    static let transactionCreate = function("SLSTransactionCreate", (@convention(c) (Int32) -> Unmanaged<CFTypeRef>?).self)
    static let transactionMoveWindow = function("SLSTransactionMoveWindowWithGroup", (@convention(c) (CFTypeRef, UInt32, CGPoint) -> Int32).self)
    static let transactionOrderWindow = function("SLSTransactionOrderWindow", (@convention(c) (CFTypeRef, UInt32, Int32, UInt32) -> Int32).self)
    static let transactionSetWindowLevel = function("SLSTransactionSetWindowLevel", (@convention(c) (CFTypeRef, UInt32, Int32) -> Int32).self)
    static let transactionCommit = function("SLSTransactionCommit", (@convention(c) (CFTypeRef, Int32) -> Int32).self)
    static let moveWindowsToManagedSpace = function("SLSMoveWindowsToManagedSpace", (@convention(c) (Int32, CFArray, UInt64) -> Int32).self)

    // Optional: without them the configured `focus-border-radius` is used.
    static let windowQueryWindows = function("SLSWindowQueryWindows", (@convention(c) (Int32, CFArray, UInt32) -> Unmanaged<CFTypeRef>?).self)
    static let windowQueryResultCopyWindows = function(
        "SLSWindowQueryResultCopyWindows", (@convention(c) (CFTypeRef) -> Unmanaged<CFTypeRef>?).self
    )
    static let windowIteratorAdvance = function("SLSWindowIteratorAdvance", (@convention(c) (CFTypeRef) -> Bool).self)
    static let windowIteratorGetCornerRadii = function(
        "SLSWindowIteratorGetCornerRadii", (@convention(c) (CFTypeRef) -> Unmanaged<CFArray>?).self
    )

    static let isAvailable: Bool = {
        let calls: [Any?] = [
            mainConnectionID, newConnection, registerNotifyProc, requestNotificationsForWindows, getWindowBounds, newRegionWithRect,
            newWindow, releaseWindow, setWindowResolution, setWindowOpacity, setWindowTags, setShadowProperties, setWindowShape,
            windowContextCreate, flushWindowContentRegion, freezeWindow, thawWindow, transactionCreate,
            transactionMoveWindow, transactionOrderWindow, transactionSetWindowLevel, transactionCommit, moveWindowsToManagedSpace
        ]
        return calls.allSatisfy { $0 != nil }
    }()

    /// A window's frame, origin top left like Accessibility frames.
    static func bounds(of windowID: CGWindowID, connection: Int32) -> CGRect? {
        var bounds = CGRect.zero
        guard let getWindowBounds, getWindowBounds(connection, windowID, &bounds) == 0 else {
            return nil
        }
        return bounds
    }

    /// The window's own corner radius (it differs per app on macOS 27), if the window server reports one.
    static func cornerRadius(of windowID: CGWindowID, connection: Int32) -> CGFloat? {
        guard let windowQueryWindows, let windowQueryResultCopyWindows, let windowIteratorAdvance, let windowIteratorGetCornerRadii,
              let query = windowQueryWindows(connection, [NSNumber(value: windowID)] as CFArray, 0)?.takeRetainedValue(),
              let iterator = windowQueryResultCopyWindows(query)?.takeRetainedValue(),
              windowIteratorAdvance(iterator),
              let radii = windowIteratorGetCornerRadii(iterator)?.takeRetainedValue() as? [NSNumber],
              let radius = radii.first?.doubleValue, radius > 0 else {
            return nil
        }
        return CGFloat(radius)
    }

    static func region(_ rect: CGRect) -> CFTypeRef? {
        var rect = rect
        var region: Unmanaged<CFTypeRef>?
        guard let newRegionWithRect, newRegionWithRect(&rect, &region) == 0 else {
            return nil
        }
        return region?.takeRetainedValue()
    }

    /// Runs the changes in one window-server transaction.
    static func transaction(_ connection: Int32, _ changes: (CFTypeRef) -> Void) {
        guard let transactionCreate, let transactionCommit, let transaction = transactionCreate(connection)?.takeRetainedValue() else {
            return
        }
        changes(transaction)
        _ = transactionCommit(transaction, 0)
    }
}

/// Draws the border into an overlay of `size` around `windowRect`, both with origin bottom left.
/// Nothing is drawn over the window itself, not even the inner half of the glow.
enum FocusBorderDrawing {
    static func draw(in context: CGContext, size: CGSize, windowRect: CGRect, appearance: FocusBorderAppearance) {
        let bounds = CGRect(origin: .zero, size: size)
        context.clear(bounds)

        guard windowRect.width > 0, windowRect.height > 0 else {
            return
        }

        let ringRect = windowRect.insetBy(dx: -appearance.ringWidth / 2, dy: -appearance.ringWidth / 2)
        let ringRadius = appearance.radius + appearance.ringWidth / 2
        let ringPath = CGPath(roundedRect: ringRect, cornerWidth: ringRadius, cornerHeight: ringRadius, transform: nil)

        context.saveGState()
        defer { context.restoreGState() }

        let outside = CGMutablePath()
        outside.addRect(bounds)
        outside.addPath(CGPath(roundedRect: windowRect, cornerWidth: appearance.radius, cornerHeight: appearance.radius, transform: nil))
        context.addPath(outside)
        context.clip(using: .evenOdd)

        context.setLineWidth(appearance.ringWidth)
        switch appearance.style {
        case .solid:
            context.setStrokeColor(appearance.color.cgColor)
            context.addPath(ringPath)
            context.strokePath()
        case .glow:
            let color = appearance.color.cgColor
            context.setShadow(offset: .zero, blur: 2 * appearance.width, color: color.copy(alpha: 0.9 * color.alpha))
            context.setStrokeColor(color)
            context.addPath(ringPath)
            context.strokePath()
        case .gradient:
            let colors = appearance.gradient.map(\.cgColor) as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: nil) else {
                return
            }
            context.addPath(ringPath)
            context.replacePathWithStrokedPath()
            context.clip()
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: 0), options: [])
        }
    }
}

/// The border window. All window-server work runs on its own serial queue; callers only post to it.
final class WindowServerBorder {
    private let queue = DispatchQueue(label: "Ametrine.FocusBorder", qos: .userInteractive)

    // Owned by `queue`.
    private var connection: Int32 = 0
    private var borderWindowID: UInt32 = 0
    private var context: CGContext?
    private var drawnSize: CGSize?
    private var drawnWindowRect: CGRect?
    private var drawnAppearance: FocusBorderAppearance?
    private var targetWindowID: CGWindowID?
    private var appearance: FocusBorderAppearance?
    private var spaceID: Int?
    private var scale: CGFloat = 2
    /// The target's own corner radius, read when the border moves to it.
    private var windowRadius: CGFloat?
    /// The target's bounds the border was last put around.
    private var followedBounds: CGRect?
    /// Move and resize events reach Ametrine through its main thread, which is busy with the same window's Accessibility events
    /// during a drag or resize, so they come late. After an event, this timer asks the window server for the window's bounds
    /// about 120 times a second, on the border's queue, until the window has been still for a quarter of a second.
    private var poller: DispatchSourceTimer?
    private var lastChange = DispatchTime.now()

    /// The window-server events arrive through a C callback, which can't capture; it finds the border here.
    private static weak var followed: WindowServerBorder?

    private static let handler: SkyLight.NotifyHandler = { _, data, length, _ in
        guard let data, length >= MemoryLayout<UInt32>.size else {
            return
        }
        let windowID = data.loadUnaligned(as: UInt32.self)
        WindowServerBorder.followed?.windowDidChange(windowID)
    }

    /// Nil when the private calls aren't there.
    init?() {
        guard SkyLight.isAvailable, let newConnection = SkyLight.newConnection, let registerNotifyProc = SkyLight.registerNotifyProc else {
            return nil
        }

        var connection: Int32 = 0
        guard newConnection(0, &connection) == 0, connection != 0,
              registerNotifyProc(WindowServerBorder.handler, SkyLight.windowMoved, nil) == 0,
              registerNotifyProc(WindowServerBorder.handler, SkyLight.windowResized, nil) == 0 else {
            return nil
        }

        self.connection = connection
        WindowServerBorder.followed = self
    }

    /// Puts the border around the window and keeps it there as the window moves or resizes.
    func show(windowID: CGWindowID, appearance: FocusBorderAppearance, spaceID: Int?, scale: CGFloat) {
        if let mainConnectionID = SkyLight.mainConnectionID, let requestNotifications = SkyLight.requestNotificationsForWindows {
            var windowIDs = [UInt32(windowID)]
            _ = requestNotifications(mainConnectionID(), &windowIDs, 1)
        }

        queue.async {
            if windowID != self.targetWindowID {
                self.windowRadius = SkyLight.cornerRadius(of: windowID, connection: self.connection)
            }
            self.targetWindowID = windowID
            self.appearance = appearance
            self.scale = scale
            if spaceID != self.spaceID {
                self.spaceID = spaceID
                self.moveToSpace()
            }
            guard let bounds = SkyLight.bounds(of: windowID, connection: self.connection) else {
                return
            }
            self.update(around: bounds, orderFront: true)
        }
    }

    func hide() {
        queue.async {
            self.targetWindowID = nil
            self.stopPolling()
            guard self.borderWindowID != 0, let orderWindow = SkyLight.transactionOrderWindow else {
                return
            }
            SkyLight.transaction(self.connection) { _ = orderWindow($0, self.borderWindowID, 0, 0) }
        }
    }

    private func windowDidChange(_ windowID: CGWindowID) {
        queue.async {
            guard windowID == self.targetWindowID else {
                return
            }
            self.follow()
            self.startPolling()
        }
    }

    /// Catches up with the target: a move only shifts the border window, a new size redraws it.
    private func follow() {
        guard let targetWindowID, let bounds = SkyLight.bounds(of: targetWindowID, connection: connection), bounds != followedBounds else {
            return
        }
        lastChange = .now()
        update(around: bounds, orderFront: false)
    }

    private func startPolling() {
        guard poller == nil else {
            return
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .nanoseconds(1_000_000_000 / 120), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }
            self.follow()
            if DispatchTime.now().uptimeNanoseconds - self.lastChange.uptimeNanoseconds > 250_000_000 {
                self.stopPolling()
            }
        }
        poller = timer
        timer.resume()
    }

    private func stopPolling() {
        poller?.cancel()
        poller = nil
    }

    /// The configured look, with the target's own corner radius when the window server reports one.
    private var effectiveAppearance: FocusBorderAppearance? {
        guard var appearance else {
            return nil
        }
        if let windowRadius {
            appearance.radius = windowRadius
        }
        return appearance
    }

    /// Puts the border around the bounds. Reshapes and redraws only when the size, the window's place inside the border window,
    /// or the look changed, with the border window frozen so no half-done border shows; otherwise only moves it. Orders it in if
    /// asked. Screen updates are never held: that paused the whole screen, and a window being resized showed blank between its
    /// new size and its new content.
    private func update(around bounds: CGRect, orderFront: Bool) {
        guard let appearance = effectiveAppearance else {
            return
        }

        // Whole points: the window server rounds a window's origin, which shifted a ring of 1.5 pt half a point left and up.
        let frame = appearance.windowServerFrame(forWindowFrame: bounds)
        guard frame.width > 0, frame.height > 0 else {
            return
        }
        // Drawing coordinates have their origin bottom left.
        let windowRect = CGRect(x: bounds.minX - frame.minX, y: frame.maxY - bounds.maxY, width: bounds.width, height: bounds.height)

        if borderWindowID == 0 && !createWindow(size: frame.size) {
            return
        }
        followedBounds = bounds

        let needsDrawing = frame.size != drawnSize || windowRect != drawnWindowRect || appearance != drawnAppearance
        if needsDrawing {
            _ = SkyLight.freezeWindow?(connection, borderWindowID, nil)
            // The offset places the window: at its final origin, never at the screen's corner.
            if let region = SkyLight.region(CGRect(origin: .zero, size: frame.size)) {
                _ = SkyLight.setWindowShape?(connection, borderWindowID, Float(frame.origin.x), Float(frame.origin.y), region)
            }
            if let context {
                FocusBorderDrawing.draw(in: context, size: frame.size, windowRect: windowRect, appearance: appearance)
                context.flush()
            }
            _ = SkyLight.flushWindowContentRegion?(connection, borderWindowID, nil)
            _ = SkyLight.thawWindow?(connection, borderWindowID)
            drawnSize = frame.size
            drawnWindowRect = windowRect
            drawnAppearance = appearance
        }

        SkyLight.transaction(connection) { transaction in
            _ = SkyLight.transactionMoveWindow?(transaction, borderWindowID, frame.origin)
            if orderFront {
                // One level above app windows: apps raise their own window whenever they like, which would cover a border kept
                // just above it. Menus and floating panels sit higher and still cover the border.
                _ = SkyLight.transactionSetWindowLevel?(transaction, borderWindowID, Int32(NSWindow.Level.normal.rawValue + 1))
                _ = SkyLight.transactionOrderWindow?(transaction, borderWindowID, 1, 0)
            }
        }
    }

    private func createWindow(size: CGSize) -> Bool {
        guard let region = SkyLight.region(CGRect(origin: .zero, size: size)), let newWindow = SkyLight.newWindow else {
            return false
        }

        var windowID: UInt32 = 0
        guard newWindow(connection, 2 /* kCGBackingStoreBuffered */, -9999, -9999, region, &windowID) == 0, windowID != 0 else {
            log.warning("Focus border: couldn't create the border window")
            return false
        }

        borderWindowID = windowID
        _ = SkyLight.setWindowResolution?(connection, windowID, Double(scale))
        // The tags window tools set on overlay windows (click-through, kept out of window lists).
        var tags: UInt64 = (1 << 1) | (1 << 9)
        _ = SkyLight.setWindowTags?(connection, windowID, &tags, 64)
        _ = SkyLight.setWindowOpacity?(connection, windowID, false)
        _ = SkyLight.setShadowProperties?(windowID, ["com.apple.WindowShadowDensity": 0] as CFDictionary)
        context = SkyLight.windowContextCreate?(connection, windowID, nil)?.takeRetainedValue()
        context?.interpolationQuality = .none
        moveToSpace()
        return context != nil
    }

    /// Puts the border on the target's Space, so it slides away with a Space switch like the window does.
    private func moveToSpace() {
        guard borderWindowID != 0, let spaceID, let moveWindows = SkyLight.moveWindowsToManagedSpace else {
            return
        }
        _ = moveWindows(connection, [NSNumber(value: borderWindowID)] as CFArray, UInt64(spaceID))
    }
}
