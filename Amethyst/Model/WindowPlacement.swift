//
//  WindowPlacement.swift
//  Amethyst
//

import Foundation

/**
 Why a tracked window tiles or floats, recorded when the decision is made so that `explain-window` reports what actually happened rather than what the rules would say now.

 The `floating` cases describe which part of the `floating` list matched; whether that means floating or tiling depends on `floating-is-blacklist`.
 */
enum PlacementReason: Equatable {
    /// The application is in `floating` with no `window-titles`.
    case listed(id: String)
    /// A `window-titles` pattern of the application's `floating` entry matched the title.
    case titleMatched(pattern: String, id: String)
    /// The application is in `floating`, but none of its `window-titles` patterns matched the title.
    case titleNotMatched(id: String)
    /// The application isn't in `floating`.
    case notListed
    /// `float-small-windows`: the window was smaller than `small-window-size` in both directions.
    case smallWindow(threshold: Int)
    /// The window's application wasn't running any more.
    case noRunningApplication
    /// `floating-secondary-windows`: the application already had an anchor on the window's space.
    case secondaryWindow
    /// `floating-secondary-windows`: the window's space stayed unknown, so it floated to be safe.
    case secondaryWindowSpaceUnknown
    /// `toggle-float`.
    case toggled
}

/// A float decision of the regular rules (`floating`, `float-small-windows`) together with its reason.
struct FloatDecision: Equatable {
    let float: DefaultFloat
    let reason: PlacementReason
}

extension Reliable {
    func map<U>(_ transform: (T) -> U) -> Reliable<U> {
        switch self {
        case let .reliable(value):
            return .reliable(transform(value))
        case let .unreliable(value):
            return .unreliable(transform(value))
        }
    }
}

/// The text `explain-window` shows for the focused window: what it is (tiled, floating, not managed) and why.
enum WindowExplanation {
    enum State: Equatable {
        /// Not a standard, movable window, e.g. a dialog, sheet or panel.
        case notStandard
        /// A standard window that isn't tracked (yet).
        case notTracked
        case floating
        case tiled
    }

    struct Input: Equatable {
        var state: State
        var reason: PlacementReason?
        var floatingIsAllowList = false
        var tilingEnabled = true
        var isFloatingLayout = false
        var isSecondaryWindowAnchor = false
        var tiledCount = 0
        var windowMaxCount: Int?
    }

    static func text(for input: Input) -> (title: String, description: String) {
        switch input.state {
        case .notStandard:
            return ("Not managed", "not a standard window (dialog, sheet or panel)")
        case .notTracked:
            return ("Not managed", "not tracked yet · try reevaluate-windows")
        case .floating:
            return ("Floating", reasonText(input.reason, floating: true, allowList: input.floatingIsAllowList))
        case .tiled:
            guard input.tilingEnabled else {
                return ("Floating", "tiling is off")
            }

            guard !input.isFloatingLayout else {
                return ("Floating", "Floating layout")
            }

            var parts = [reasonText(input.reason, floating: false, allowList: input.floatingIsAllowList)]
            if input.isSecondaryWindowAnchor {
                parts.append("anchor of its app on this space")
            }
            if let windowMaxCount = input.windowMaxCount {
                parts.append("\(input.tiledCount) of \(windowMaxCount) windows")
            } else {
                parts.append("\(input.tiledCount) windows, no limit")
            }
            return ("Tiled", parts.joined(separator: " · "))
        }
    }

    /// The reason in a few words, as shown in the HUD and the log.
    static func reasonText(_ reason: PlacementReason?, floating: Bool, allowList: Bool) -> String {
        let allowListNote = allowList ? " (allow list)" : ""

        switch reason {
        case let .listed(id)?:
            return "in floating list (\(id))\(allowListNote)"
        case let .titleMatched(pattern, id)?:
            return "title rule \(pattern) (\(id))\(allowListNote)"
        case let .titleNotMatched(id)?:
            return "no title rule matches (\(id))\(allowListNote)"
        case .notListed?:
            return allowList ? "not in floating list (allow list)" : "no floating rule"
        case let .smallWindow(threshold)?:
            return "small window (under \(threshold) pt)"
        case .noRunningApplication?:
            return "its app isn't running"
        case .secondaryWindow?:
            return "secondary window (floating-secondary-windows)"
        case .secondaryWindowSpaceUnknown?:
            return "secondary window, space unknown (floating-secondary-windows)"
        case .toggled?:
            return floating ? "floated by hand (toggle-float)" : "tiled by hand (toggle-float)"
        case nil:
            return "reason not recorded"
        }
    }
}
