//
//  WindowsInfo.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 3/5/23.
//  Copyright © 2023 Ian Ynda-Hummel. All rights reserved.
//

import ArgumentParser
import Cocoa
import Foundation
import Silica

extension AXWindow {
    func debugInfo(redactTitles: Bool) -> String {
        let screenDescription = screen().map { AMScreen(screen: $0).debugDescription() }

        return """
        \tTitle: \(redactTitles ? "<redacted>" : title() ?? "<no title>")
        \tFrame: \(frame())
        \tid: \(windowID())
        \(screenDescription ?? "Screen: unknown")
        \tisActive: \(isActive())
        \tisOnScreen: \(isOnScreen())
        \tisFocused: \(isFocused())
        \tshouldBeManaged: \(shouldBeManaged())
        \tshouldFloat: \(shouldFloat())
        """
    }
}

struct Windows: ParsableCommand {
    @Flag(help: "Include windows of unmanaged applications.")
    var includeUnmanaged = false

    @Flag(help: "Redact window titles.")
    var redactWindowTitles = false

    mutating func run() throws {
        // The command runs in the calling process (e.g. a terminal), which needs Accessibility of its own; without it every attribute reads empty.
        guard AXIsProcessTrusted() else {
            FileHandle.standardError.write(Data(
                "error: the app running this command (e.g. your terminal) needs Accessibility permission: System Settings → Privacy & Security → Accessibility\n".utf8
            ))
            throw ExitCode.failure
        }

        let applications = NSWorkspace.shared.runningApplications
        for application in applications where includeUnmanaged || application.isManageable == .manageable {
            let app = SIApplication(runningApplication: application)
            print("\(app.title() ?? "<no title>") (pid \(app.pid()))")
            for window in app.windows() {
                // Some apps list elements that aren't windows; one of them mustn't end the listing.
                guard let axWindow = AXWindow(element: window) else {
                    print("\t<not a window: role \(window.string(forKey: kAXRoleAttribute as CFString) ?? "unknown")>\n")
                    continue
                }

                print(axWindow.debugInfo(redactTitles: redactWindowTitles))
                print("")
            }
            fflush(stdout)
        }
    }
}
