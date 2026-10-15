//
//  WindowServerBorder.swift
//  Amethyst
//
//  The focus border as eight small windows of its own in the window server (four corners, four edges), drawn with Core
//  Graphics once and then only moved, and the edges stretched, in window-server transactions off the main thread. A resize
//  never redraws or reshapes anything, which is what flickered. Uses private SkyLight calls, the same ones window tools such as
//  JankyBorders and yabai rely on, looked up at runtime: without them FocusBorder falls back to an AppKit panel.
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
    static let windowContextCreate = function("SLWindowContextCreate", (@convention(c) (Int32, UInt32, CFDictionary?) -> Unmanaged<CGContext>?).self)
    static let flushWindowContentRegion = function("SLSFlushWindowContentRegion", (@convention(c) (Int32, UInt32, UnsafeMutableRawPointer?) -> Int32).self)
    static let transactionCreate = function("SLSTransactionCreate", (@convention(c) (Int32) -> Unmanaged<CFTypeRef>?).self)
    static let transactionMoveWindow = function("SLSTransactionMoveWindowWithGroup", (@convention(c) (CFTypeRef, UInt32, CGPoint) -> Int32).self)
    static let transactionOrderWindow = function("SLSTransactionOrderWindow", (@convention(c) (CFTypeRef, UInt32, Int32, UInt32) -> Int32).self)
    static let transactionSetWindowLevel = function("SLSTransactionSetWindowLevel", (@convention(c) (CFTypeRef, UInt32, Int32) -> Int32).self)
    static let transactionSetWindowTransform = function(
        "SLSTransactionSetWindowTransform", (@convention(c) (CFTypeRef, UInt32, Int32, Int32, CGAffineTransform) -> Int32).self
    )
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
            newWindow, releaseWindow, setWindowResolution, setWindowOpacity, setWindowTags, setShadowProperties,
            windowContextCreate, flushWindowContentRegion, transactionCreate, transactionMoveWindow, transactionOrderWindow,
            transactionSetWindowLevel, transactionSetWindowTransform, transactionCommit, moveWindowsToManagedSpace
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

/// Where the border's eight pieces go around a window, origin top left. The corners keep their size; the edges span between
/// them, so a resize only moves corners and stretches edges.
struct FocusBorderPieces: Equatable {
    enum Piece: CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }

    /// How far the border reaches beyond each side of the window.
    let left: CGFloat
    let top: CGFloat
    let right: CGFloat
    let bottom: CGFloat
    /// How far the corner pieces reach into the window along each side: its corner radius, in whole points.
    let corner: CGFloat

    /// The pieces for a border drawn around `windowFrame`: the overlay is `appearance.windowServerFrame`, in whole points.
    init(windowFrame: CGRect, appearance: FocusBorderAppearance) {
        let overlay = appearance.windowServerFrame(forWindowFrame: windowFrame)
        left = windowFrame.minX - overlay.minX
        top = windowFrame.minY - overlay.minY
        right = overlay.maxX - windowFrame.maxX
        bottom = overlay.maxY - windowFrame.maxY
        corner = ceil(min(appearance.radius, windowFrame.width / 2, windowFrame.height / 2))
    }

    /// The rects around a window; edges of a window too small for its corners are zero long.
    func rects(around window: CGRect) -> [Piece: CGRect] {
        let width = max(window.width - 2 * corner, 0)
        let height = max(window.height - 2 * corner, 0)
        return [
            .topLeft: CGRect(x: window.minX - left, y: window.minY - top, width: left + corner, height: top + corner),
            .top: CGRect(x: window.minX + corner, y: window.minY - top, width: width, height: top),
            .topRight: CGRect(x: window.maxX - corner, y: window.minY - top, width: corner + right, height: top + corner),
            .right: CGRect(x: window.maxX, y: window.minY + corner, width: right, height: height),
            .bottomRight: CGRect(x: window.maxX - corner, y: window.maxY - corner, width: corner + right, height: corner + bottom),
            .bottom: CGRect(x: window.minX + corner, y: window.maxY, width: width, height: bottom),
            .bottomLeft: CGRect(x: window.minX - left, y: window.maxY - corner, width: left + corner, height: corner + bottom),
            .left: CGRect(x: window.minX - left, y: window.minY + corner, width: left, height: height)
        ]
    }

    /// The window-server transform that shows a piece drawn at `drawnSize` in `rect`: it maps screen points to the piece's own,
    /// so an edge drawn at one length is stretched to another.
    static func transform(showing drawnSize: CGSize, in rect: CGRect) -> CGAffineTransform {
        let scaleX = drawnSize.width / max(rect.width, 0.001)
        let scaleY = drawnSize.height / max(rect.height, 0.001)
        return CGAffineTransform(a: scaleX, b: 0, c: 0, d: scaleY, tx: -rect.minX * scaleX, ty: -rect.minY * scaleY)
    }
}

/// The border. All window-server work runs on its own serial queue; callers only post to it.
final class WindowServerBorder {
    private struct DrawnPiece {
        let windowID: UInt32
        let context: CGContext
        let drawnSize: CGSize
    }

    /// What the current pieces were drawn for; anything else needs a new set.
    private struct Drawing: Equatable {
        let targetWindowID: CGWindowID
        let appearance: FocusBorderAppearance
        let pieces: FocusBorderPieces
    }

    private let queue = DispatchQueue(label: "Ametrine.FocusBorder", qos: .userInteractive)

    // Owned by `queue`.
    private var connection: Int32 = 0
    private var pieces: [FocusBorderPieces.Piece: DrawnPiece] = [:]
    private var drawing: Drawing?
    private var targetWindowID: CGWindowID?
    private var spaceID: Int?
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
            let spaceChanged = spaceID != self.spaceID
            self.spaceID = spaceID
            guard let bounds = SkyLight.bounds(of: windowID, connection: self.connection) else {
                // Never leave the border where the last window was.
                log.debug("Focus border: can't read the bounds of #\(windowID), hiding")
                self.orderOutPieces()
                return
            }

            var appearance = appearance
            if let windowRadius = self.windowRadius {
                appearance.radius = windowRadius
            }
            let piecesLayout = self.drawing?.targetWindowID == windowID && self.drawing?.appearance == appearance
                ? self.drawing!.pieces
                : FocusBorderPieces(windowFrame: bounds, appearance: appearance)
            let drawing = Drawing(targetWindowID: windowID, appearance: appearance, pieces: piecesLayout)

            if drawing != self.drawing || self.pieces.isEmpty {
                log.debug("Focus border: drawing for #\(windowID) at \(bounds)")
                self.replacePieces(drawing: drawing, around: bounds, scale: scale)
            } else {
                if spaceChanged {
                    self.moveToSpace(self.pieces.values.map(\.windowID))
                }
                self.place(around: bounds, orderFront: true)
            }
            // Ametrine often moves the window right after focusing it (a close pulls a window into main); its move events can
            // arrive before the border switched to it and be dropped. Polling for a moment catches up either way.
            self.lastChange = .now()
            self.startPolling()
        }
    }

    func hide() {
        queue.async {
            self.targetWindowID = nil
            self.stopPolling()
            self.orderOutPieces()
        }
    }

    private func orderOutPieces() {
        let windowIDs = pieces.values.map(\.windowID)
        guard !windowIDs.isEmpty, let orderWindow = SkyLight.transactionOrderWindow else {
            return
        }
        SkyLight.transaction(connection) { transaction in
            for windowID in windowIDs {
                _ = orderWindow(transaction, windowID, 0, 0)
            }
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

    /// Catches up with the target: corners move, edges move and stretch, nothing is drawn.
    private func follow() {
        guard let targetWindowID, let bounds = SkyLight.bounds(of: targetWindowID, connection: connection), bounds != followedBounds else {
            return
        }
        lastChange = .now()
        place(around: bounds, orderFront: false)
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

    /// Moves every piece into place around the bounds in one transaction, so they never come apart on screen.
    private func place(around bounds: CGRect, orderFront: Bool) {
        guard let drawing else {
            return
        }
        followedBounds = bounds
        let rects = drawing.pieces.rects(around: bounds)
        SkyLight.transaction(connection) { transaction in
            for (piece, drawn) in pieces {
                guard let rect = rects[piece] else {
                    continue
                }
                self.position(drawn, in: rect, transaction: transaction, orderFront: orderFront)
            }
        }
    }

    private func position(_ drawn: DrawnPiece, in rect: CGRect, transaction: CFTypeRef, orderFront: Bool) {
        _ = SkyLight.transactionMoveWindow?(transaction, drawn.windowID, rect.origin)
        _ = SkyLight.transactionSetWindowTransform?(
            transaction, drawn.windowID, 0, 0, FocusBorderPieces.transform(showing: drawn.drawnSize, in: rect)
        )
        if orderFront {
            // One level above app windows: apps raise their own window whenever they like, which would cover a border kept
            // just above it. Menus and floating panels sit higher and still cover the border.
            _ = SkyLight.transactionSetWindowLevel?(transaction, drawn.windowID, Int32(NSWindow.Level.normal.rawValue + 1))
            _ = SkyLight.transactionOrderWindow?(transaction, drawn.windowID, 1, 0)
        }
    }

    /// Draws a new set of pieces off screen and swaps it in for the old one in one transaction: no frame shows half a border.
    private func replacePieces(drawing: Drawing, around bounds: CGRect, scale: CGFloat) {
        let overlay = drawing.appearance.windowServerFrame(forWindowFrame: bounds)
        // Drawing coordinates have their origin bottom left.
        let windowRect = CGRect(x: bounds.minX - overlay.minX, y: overlay.maxY - bounds.maxY, width: bounds.width, height: bounds.height)
        let rects = drawing.pieces.rects(around: bounds)

        var newPieces: [FocusBorderPieces.Piece: DrawnPiece] = [:]
        for (piece, rect) in rects {
            // A zero-long edge is drawn one point long and squeezed.
            let size = CGSize(width: max(rect.width, 1), height: max(rect.height, 1))
            guard let drawn = createPiece(size: size, scale: scale) else {
                release(Array(newPieces.values))
                return
            }
            drawn.context.saveGState()
            drawn.context.translateBy(x: -(rect.minX - overlay.minX), y: -(overlay.maxY - rect.maxY))
            FocusBorderDrawing.draw(in: drawn.context, size: overlay.size, windowRect: windowRect, appearance: drawing.appearance)
            drawn.context.restoreGState()
            drawn.context.flush()
            _ = SkyLight.flushWindowContentRegion?(connection, drawn.windowID, nil)
            newPieces[piece] = drawn
        }
        moveToSpace(newPieces.values.map(\.windowID))

        let oldPieces = Array(pieces.values)
        SkyLight.transaction(connection) { transaction in
            for (piece, drawn) in newPieces {
                guard let rect = rects[piece] else {
                    continue
                }
                self.position(drawn, in: rect, transaction: transaction, orderFront: true)
            }
            for old in oldPieces {
                _ = SkyLight.transactionOrderWindow?(transaction, old.windowID, 0, 0)
            }
        }
        release(oldPieces)

        pieces = newPieces
        self.drawing = drawing
        followedBounds = bounds
    }

    private func createPiece(size: CGSize, scale: CGFloat) -> DrawnPiece? {
        guard let region = SkyLight.region(CGRect(origin: .zero, size: size)), let newWindow = SkyLight.newWindow else {
            return nil
        }

        var windowID: UInt32 = 0
        guard newWindow(connection, 2 /* kCGBackingStoreBuffered */, -9999, -9999, region, &windowID) == 0, windowID != 0 else {
            log.warning("Focus border: couldn't create a border window")
            return nil
        }

        _ = SkyLight.setWindowResolution?(connection, windowID, Double(scale))
        // The tags window tools set on overlay windows (click-through, kept out of window lists).
        var tags: UInt64 = (1 << 1) | (1 << 9)
        _ = SkyLight.setWindowTags?(connection, windowID, &tags, 64)
        _ = SkyLight.setWindowOpacity?(connection, windowID, false)
        _ = SkyLight.setShadowProperties?(windowID, ["com.apple.WindowShadowDensity": 0] as CFDictionary)
        guard let context = SkyLight.windowContextCreate?(connection, windowID, nil)?.takeRetainedValue() else {
            _ = SkyLight.releaseWindow?(connection, windowID)
            return nil
        }
        context.interpolationQuality = .none
        return DrawnPiece(windowID: windowID, context: context, drawnSize: size)
    }

    private func release(_ drawnPieces: [DrawnPiece]) {
        for drawn in drawnPieces {
            _ = SkyLight.releaseWindow?(connection, drawn.windowID)
        }
    }

    /// Puts the pieces on the target's Space, so they slide away with a Space switch like the window does.
    private func moveToSpace(_ windowIDs: [UInt32]) {
        guard !windowIDs.isEmpty, let spaceID, let moveWindows = SkyLight.moveWindowsToManagedSpace else {
            return
        }
        _ = moveWindows(connection, windowIDs.map { NSNumber(value: $0) } as CFArray, UInt64(spaceID))
    }
}
