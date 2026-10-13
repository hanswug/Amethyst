//
//  main.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 2/24/20.
//  Copyright © 2020 Ian Ynda-Hummel. All rights reserved.
//

import ArgumentParser
import Cocoa

struct Arguments: ParsableArguments {}

struct Amethyst: ParsableCommand {
    static var configuration: CommandConfiguration = CommandConfiguration(
        subcommands: [Debug.self, App.self],
        defaultSubcommand: App.self
    )
}

struct App: ParsableCommand {
    static var configuration: CommandConfiguration = CommandConfiguration(
        abstract: "Run the Amethyst application."
    )

    // Read by AppDelegate from CommandLine.arguments; declared here so the parser accepts it.
    @Flag(name: .customLong("log"), help: "Log to the system log.")
    var logging = false

    mutating func run() throws {
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}

if CommandLine.arguments.contains("--debug-info") {
    print(DebugInfo.description(arguments: CommandLine.arguments))
} else if CommandLine.arguments.dropFirst().first == "test" {
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
} else {
    do {
        var command = try Amethyst.parseAsRoot()
        try command.run()
    } catch {
        Arguments.exit(withError: error)
    }
    Arguments.exit()
}
