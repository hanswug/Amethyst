//
//  UserConfigurationTests.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/15/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Cocoa
import Nimble
import Quick
import SwiftyJSON
import Yams

class TestConfigurationStorage: ConfigurationStorage {
    var storage: [ConfigurationKey: Any] = [:]

    func object(forKey key: ConfigurationKey) -> Any? {
        return storage[key]
    }

    func array(forKey key: ConfigurationKey) -> [Any]? {
        return storage[key] as? [Any]
    }

    func bool(forKey key: ConfigurationKey) -> Bool {
        return (storage[key] as? Bool) ?? false
    }

    func float(forKey key: ConfigurationKey) -> Float {
        return (storage[key] as? Float) ?? 0
    }

    func stringArray(forKey key: ConfigurationKey) -> [String]? {
        return storage[key] as? [String]
    }

    func set(_ value: Any?, forKey key: ConfigurationKey) {
        storage[key] = value
    }

    func set(_ value: Bool, forKey key: ConfigurationKey) {
        storage[key] = value
    }
}

class UserConfigurationTests: QuickSpec {
    private class TestHotKeyRegistrar: HotKeyRegistrar {
        private(set) var keyString: String?
        private(set) var modifiers: AMModifierFlags?
        private(set) var handler: (() -> Void)?
        private(set) var defaultsKey: String?
        private(set) var override: Bool?

        init() {}

        func registerHotKey(with string: String?, modifiers: AMModifierFlags?, handler: @escaping () -> Void, defaultsKey: String, override: Bool) {
            keyString = string
            self.modifiers = modifiers
            self.handler = handler
            self.defaultsKey = defaultsKey
            self.override = override
        }
    }

    private class TestBundleIdentifiable: BundleIdentifiable {
        var bundleIdentifier: String?
    }

    override func spec() {
        describe("constructing commands") {
            context("overrides") {
                it("when user configuration exists") {
                    var configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configurationYAML = nil
                    configuration.configurationJSON = JSON(localConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    var registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())

                    configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.configurationYAML = localConfiguration
                    configuration.configurationJSON = nil
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())
                }

                it("when custom mod1 is specified") {
                    var configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "mod1": [
                            "command"
                        ]
                    ]
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configurationYAML = nil
                    configuration.configurationJSON = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    var registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())

                    configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.configurationYAML = localConfiguration
                    configuration.configurationJSON = nil
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())

                }

                it("when custom mod2 is specified") {
                    var configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "mod2": [
                            "command"
                        ]
                    ]
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configurationJSON = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    var registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())

                    configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.configurationYAML = localConfiguration
                    configuration.configurationJSON = nil
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.override).to(beTrue())
                }
            }

            context("takes command") {
                it("from local configuration over default") {
                    var configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let localConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "2"
                        ]
                    ]
                    configuration.configurationJSON = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    var registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.keyString).to(equal("1"))

                    configuration = UserConfiguration(storage: TestConfigurationStorage())
                    configuration.configurationJSON = JSON(localConfiguration)
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(registrar.keyString).to(equal("1"))
                }

                it("from default in absence of local configuration") {
                    let configuration = UserConfiguration(storage: TestConfigurationStorage())
                    let defaultConfiguration: [String: Any] = [
                        "test": [
                            "mod": "mod1",
                            "key": "1"
                        ]
                    ]
                    configuration.configurationJSON = JSON([:])
                    configuration.defaultConfiguration = JSON(defaultConfiguration)
                    configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                    let registrar = TestHotKeyRegistrar()

                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                    expect(configuration.defaultConfiguration?["test"]["key"].string).to(equal("1"))
                    expect(registrar.keyString).to(equal("1"))
                }
            }

            it("does not crash for malformed commands") {
                var configuration = UserConfiguration(storage: TestConfigurationStorage())
                let localConfiguration: [String: Any] = [
                    "test": [
                        "key": "2"
                    ]
                ]
                let defaultConfiguration: [String: Any] = [
                    "test": [
                        "mod": "mod1",
                        "key": "2"
                    ]
                ]
                configuration.configurationYAML = nil
                configuration.configurationJSON = JSON(localConfiguration)
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                var registrar = TestHotKeyRegistrar()

                expect {
                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})
                }.toNot(throwError())

                configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.configurationYAML = localConfiguration
                configuration.configurationJSON = nil
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])

                registrar = TestHotKeyRegistrar()

                expect {
                    configuration.constructCommand(for: registrar, commandKey: "test", handler: {})
                }.toNot(throwError())
            }
        }

        describe("floating application") {
            it("is not floating by default") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set([] as Any?, forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.notFloating)))
            }

            it("floats for exact matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.test.Test"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.floating)))
            }

            it("floats for wildcard matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.test.*"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.floating)))
            }

            it("floats for prefixed wildcard matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["*.Test"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.floating)))
            }

            it("floats for inline wildcard matches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.*.Test"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.foo.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.floating)))
            }

            it("does not float for exact mismatches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.test.Other"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.notFloating)))
            }

            it("does not float for wildcard mismatches") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                storage.set(["test.other.*"], forKey: .floatingBundleIdentifiers)

                let bundleIdentifiable = TestBundleIdentifiable()
                let title = UUID().uuidString
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.notFloating)))
            }

            context("as whitelist") {
                it("does not float for a matching window title") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let floatingBundle = FloatingBundle(id: "test.test.Test", windowTitles: ["test"])

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([floatingBundle])

                    let bundleIdentifiable = TestBundleIdentifiable()
                    let title = "test"
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.notFloating)))
                }

                it("does not float for a matching application with no specified window titles") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)
                    storage.set(["test.test.Test"], forKey: .floatingBundleIdentifiers)

                    let bundleIdentifiable = TestBundleIdentifiable()
                    let title = UUID().uuidString
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)).to(equal(.reliable(.notFloating)))
                }

                it("floats for no specified applications") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)
                    storage.set([], forKey: .floatingBundleIdentifiers)

                    let bundleIdentifiable = TestBundleIdentifiable()
                    let title = UUID().uuidString
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    let float = configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: title)
                    expect(float).to(equal(.reliable(.floating)))
                }
            }

            context("specified window titles") {
                it("only float windows with titles") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let floatingBundle = FloatingBundle(id: "test.test.Test", windowTitles: ["test1"])

                    storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([floatingBundle])

                    let bundleIdentifiable = TestBundleIdentifiable()
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "test1")).to(equal(.reliable(.floating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "test2")).to(equal(.reliable(.notFloating)))
                }

                it("only allow windows with titles") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let floatingBundle = FloatingBundle(id: "test.test.Test", windowTitles: ["test1"])

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([floatingBundle])

                    let bundleIdentifiable = TestBundleIdentifiable()
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "test1")).to(equal(.reliable(.notFloating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "test2")).to(equal(.reliable(.floating)))
                }

                it("treats empty and nil titles as unreliable") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let floatingBundle = FloatingBundle(id: "test.test.Test", windowTitles: ["test1"])

                    storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([floatingBundle])

                    let bundleIdentifiable = TestBundleIdentifiable()
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "")).to(equal(.unreliable(.notFloating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: nil)).to(equal(.unreliable(.notFloating)))

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "")).to(equal(.unreliable(.floating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: nil)).to(equal(.unreliable(.floating)))
                }

                it("treats empty and nil titles as reliable if no title would match anyway") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)

                    storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([])

                    let bundleIdentifiable = TestBundleIdentifiable()
                    bundleIdentifiable.bundleIdentifier = "test.test.Test"

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "")).to(equal(.reliable(.notFloating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: nil)).to(equal(.reliable(.notFloating)))

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)

                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: "")).to(equal(.reliable(.floating)))
                    expect(configuration.runningApplication(bundleIdentifiable, byDefaultFloatsForTitle: nil)).to(equal(.reliable(.floating)))
                }
            }
        }

        describe("focus follows mouse") {
            it("toggles") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(true, forKey: .focusFollowsMouse)

                expect(configuration.focusFollowsMouse()).to(beTrue())

                configuration.toggleFocusFollowsMouse()

                expect(configuration.focusFollowsMouse()).to(beFalse())
            }
        }

        describe("small window size") {
            it("returns default value when not set") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                expect(configuration.smallWindowSize()).to(equal(500))
            }

            it("returns configured value when set") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(Float(300), forKey: .smallWindowSize)

                expect(configuration.smallWindowSize()).to(equal(300))
            }

            it("returns default value when set to zero") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(Float(0), forKey: .smallWindowSize)

                expect(configuration.smallWindowSize()).to(equal(500))
            }

            it("returns default value when set to negative") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set(Float(-100), forKey: .smallWindowSize)

                expect(configuration.smallWindowSize()).to(equal(500))
            }
        }

        describe("load configuration") {
            it("default configuration does not override existing configuration") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                let existingLayouts = ["wide"]
                let defaultConfiguration = [
                    "layouts": [
                        "tall"
                    ]
                ]

                storage.set(existingLayouts, forKey: .layouts)

                expect(configuration.layoutKeys()).to(equal(existingLayouts))
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutKeys()).to(equal(existingLayouts))
            }

            it("local json configuration does override existing configuration") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                let existingLayouts = ["wide"]
                let localConfiguration = [
                    "layouts": [
                        "fullscreen"
                    ]
                ]
                let defaultConfiguration = [
                    "layouts": [
                        "tall"
                    ]
                ]

                storage.set(existingLayouts, forKey: .layouts)

                expect(configuration.layoutKeys()).to(equal(existingLayouts))
                configuration.configurationYAML = nil
                configuration.configurationJSON = JSON(localConfiguration)
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutKeys()).to(equal(localConfiguration["layouts"]))
            }

            it("local yaml configuration does override existing configuration") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                let existingLayouts = ["wide"]
                let localConfiguration = [
                    "layouts": [
                        "fullscreen"
                    ]
                ]
                let defaultConfiguration = [
                    "layouts": [
                        "tall"
                    ]
                ]

                storage.set(existingLayouts, forKey: .layouts)

                expect(configuration.layoutKeys()).to(equal(existingLayouts))
                configuration.configurationYAML = localConfiguration
                configuration.configurationJSON = nil
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutKeys()).to(equal(localConfiguration["layouts"]))
            }

            it("prefers yaml over json for local configuration") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                let yamlConfiguration = [
                    "layouts": [
                        "fullscreen"
                    ]
                ]
                let jsonConfiguration = [
                    "layouts": [
                        "tall"
                    ]
                ]
                let defaultConfiguration = [
                    "layouts": [
                        "wide"
                    ]
                ]
                configuration.configurationYAML = yamlConfiguration
                configuration.configurationJSON = JSON(jsonConfiguration)
                configuration.defaultConfiguration = JSON(defaultConfiguration)
                configuration.loadConfiguration()
                expect(configuration.layoutKeys()).to(equal(yamlConfiguration["layouts"]))
            }
        }

        describe("floating bundles") {
            describe("returned") {
                it("handles both strings and objects") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let bundlesData: [Any] = [
                        "test.test.1",
                        [
                            "id": "test.test.2",
                            "window-titles": [
                                "dialog"
                            ]
                        ],
                        "test.test.3"
                    ]

                    storage.set(bundlesData, forKey: .floatingBundleIdentifiers)

                    let bundles = configuration.floatingBundles()
                    let expectedBundles = [
                        FloatingBundle(id: "test.test.1", windowTitles: []),
                        FloatingBundle(id: "test.test.2", windowTitles: ["dialog"]),
                        FloatingBundle(id: "test.test.3", windowTitles: [])
                    ]
                    expect(bundles.count).to(equal(3))
                    expect(bundles).to(equal(expectedBundles))
                }
            }

            describe("set") {
                it("assigns bundles") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let bundles = [
                        FloatingBundle(id: "test.test.1", windowTitles: []),
                        FloatingBundle(id: "test.test.2", windowTitles: ["dialog"]),
                        FloatingBundle(id: "test.test.3", windowTitles: [])
                    ]

                    configuration.setFloatingBundles(bundles)

                    let bundlesData = storage.array(forKey: .floatingBundleIdentifiers).flatMap { JSON($0) }
                    let expectedBundlesData: JSON = JSON([
                        [
                            "id": "test.test.1",
                            "window-titles": []
                        ],
                        [
                            "id": "test.test.2",
                            "window-titles": [
                                "dialog"
                            ]
                        ],
                        [
                            "id": "test.test.3",
                            "window-titles": []
                        ]
                    ])
                    expect(bundlesData).to(equal(expectedBundlesData))
                }
            }
        }

        describe("floating bundles") {
            describe("returned") {
                it("handles both strings and objects") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let bundlesData: [Any] = [
                        // Normal string
                        "test.test.1",
                        // JSON formatted
                        [
                            "id": "test.test.2",
                            "window-titles": [
                                "dialog"
                            ]
                        ],
                        // Another string
                        "test.test.3",
                        // YAML formatted
                        [
                            "test.test.4": [
                                "window-titles": [
                                    "dialog2"
                                ]
                            ]
                        ]
                    ]

                    storage.set(bundlesData, forKey: .floatingBundleIdentifiers)

                    let bundles = configuration.floatingBundles()
                    let expectedBundles = [
                        FloatingBundle(id: "test.test.1", windowTitles: []),
                        FloatingBundle(id: "test.test.2", windowTitles: ["dialog"]),
                        FloatingBundle(id: "test.test.3", windowTitles: []),
                        FloatingBundle(id: "test.test.4", windowTitles: ["dialog2"])
                    ]
                    expect(bundles.count).to(equal(4))
                    expect(bundles).to(equal(expectedBundles))
                }
            }

            describe("set") {
                it("assigns bundles") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)
                    let bundles = [
                        FloatingBundle(id: "test.test.1", windowTitles: []),
                        FloatingBundle(id: "test.test.2", windowTitles: ["dialog"]),
                        FloatingBundle(id: "test.test.3", windowTitles: [])
                    ]

                    configuration.setFloatingBundles(bundles)

                    let bundlesData = storage.array(forKey: .floatingBundleIdentifiers).flatMap { JSON($0) }
                    let expectedBundlesData: JSON = JSON([
                        [
                            "id": "test.test.1",
                            "window-titles": []
                        ],
                        [
                            "id": "test.test.2",
                            "window-titles": [
                                "dialog"
                            ]
                        ],
                        [
                            "id": "test.test.3",
                            "window-titles": []
                        ]
                    ])
                    expect(bundlesData).to(equal(expectedBundlesData))
                }
            }
        }

        describe("padding modes") {
            let modesYAML = """
            padding-modes:
              - name: full
              - name: wide
                top: 540
              - name: "27"
                left: 640
                right: 640
                top: 720
            """

            var suiteName: String!
            var stateDefaults: UserDefaults!

            beforeEach {
                suiteName = "padding-mode-tests-\(UUID().uuidString)"
                stateDefaults = UserDefaults(suiteName: suiteName)
            }

            afterEach {
                stateDefaults.removePersistentDomain(forName: suiteName)
            }

            func loadedConfiguration(_ yaml: String, storage: TestConfigurationStorage = TestConfigurationStorage()) -> UserConfiguration {
                let configuration = UserConfiguration(storage: storage, stateDefaults: stateDefaults)
                configuration.configurationYAML = try! Yams.load(yaml: yaml) as? [String: Any]
                configuration.configurationJSON = nil
                configuration.defaultConfiguration = JSON([String: Any]())
                configuration.loadConfiguration()
                return configuration
            }

            func paddings(_ configuration: UserConfiguration) -> [CGFloat] {
                return [
                    configuration.screenPaddingTop(),
                    configuration.screenPaddingBottom(),
                    configuration.screenPaddingLeft(),
                    configuration.screenPaddingRight()
                ]
            }

            func plainPaddingStorage() -> TestConfigurationStorage {
                let storage = TestConfigurationStorage()
                storage.set(Float(10), forKey: .screenPaddingTop)
                storage.set(Float(20), forKey: .screenPaddingBottom)
                storage.set(Float(30), forKey: .screenPaddingLeft)
                storage.set(Float(40), forKey: .screenPaddingRight)
                return storage
            }

            describe("parsing") {
                it("reads modes in order with omitted sides as zero") {
                    let configuration = loadedConfiguration(modesYAML)

                    expect(configuration.paddingModes()).to(equal([
                        PaddingMode(name: "full", top: 0, bottom: 0, left: 0, right: 0),
                        PaddingMode(name: "wide", top: 540, bottom: 0, left: 0, right: 0),
                        PaddingMode(name: "27", top: 720, bottom: 0, left: 640, right: 640)
                    ]))
                }

                it("accepts a bare number as the name") {
                    let configuration = loadedConfiguration("""
                    padding-modes:
                      - name: 27
                        top: 720
                    """)

                    expect(configuration.paddingModes().map { $0.name }).to(equal(["27"]))
                }

                it("skips entries without a name and repeated names") {
                    let configuration = loadedConfiguration("""
                    padding-modes:
                      - top: 100
                      - name: wide
                        top: 540
                      - just-a-string
                      - name: wide
                        top: 1
                    """)

                    expect(configuration.paddingModes()).to(equal([
                        PaddingMode(name: "wide", top: 540, bottom: 0, left: 0, right: 0)
                    ]))
                }
            }

            describe("screen padding") {
                it("uses the plain screen paddings when no modes are configured") {
                    let configuration = loadedConfiguration("layouts: [tall]", storage: plainPaddingStorage())

                    expect(configuration.activePaddingMode()).to(beNil())
                    expect(paddings(configuration)).to(equal([10, 20, 30, 40]))
                }

                it("uses the plain screen paddings while no mode is selected") {
                    let configuration = loadedConfiguration(modesYAML, storage: plainPaddingStorage())

                    expect(paddings(configuration)).to(equal([10, 20, 30, 40]))
                }

                it("uses the active mode's values") {
                    let configuration = loadedConfiguration(modesYAML, storage: plainPaddingStorage())

                    configuration.selectPaddingMode(named: "27")

                    expect(paddings(configuration)).to(equal([720, 0, 640, 640]))
                }

                it("falls back to the plain screen paddings for an unknown active name") {
                    stateDefaults.set("gone", forKey: UserConfiguration.activePaddingModeKey)
                    let configuration = loadedConfiguration(modesYAML, storage: plainPaddingStorage())

                    expect(configuration.activePaddingMode()).to(beNil())
                    expect(paddings(configuration)).to(equal([10, 20, 30, 40]))
                }
            }

            describe("active mode") {
                it("starts with padding-mode from the configuration") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    expect(configuration.activePaddingMode()?.name).to(equal("wide"))
                }

                it("accepts a bare number for padding-mode") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: 27")

                    expect(configuration.activePaddingMode()?.name).to(equal("27"))
                }

                it("prefers the selected mode over padding-mode, also after reloading the configuration") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    configuration.selectPaddingMode(named: "full")
                    configuration.loadConfiguration()

                    expect(configuration.activePaddingMode()?.name).to(equal("full"))
                }

                it("survives a restart") {
                    loadedConfiguration(modesYAML).selectPaddingMode(named: "27")

                    let relaunched = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    expect(relaunched.activePaddingMode()?.name).to(equal("27"))
                }

                it("ignores selecting an unknown name") {
                    let configuration = loadedConfiguration(modesYAML)
                    configuration.selectPaddingMode(named: "wide")

                    expect(configuration.selectPaddingMode(named: "nope")).to(beNil())
                    expect(configuration.activePaddingMode()?.name).to(equal("wide"))
                }
            }

            describe("cycling") {
                it("goes forward in order and wraps around") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    let names = (0..<3).compactMap { _ in configuration.cyclePaddingMode(forward: true)?.name }

                    expect(names).to(equal(["27", "full", "wide"]))
                }

                it("goes backward and wraps around") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    let names = (0..<3).compactMap { _ in configuration.cyclePaddingMode(forward: false)?.name }

                    expect(names).to(equal(["full", "27", "wide"]))
                }

                it("starts at the first or last mode when none is active") {
                    expect(loadedConfiguration(modesYAML).cyclePaddingMode(forward: true)?.name).to(equal("full"))

                    stateDefaults.removeObject(forKey: UserConfiguration.activePaddingModeKey)
                    expect(loadedConfiguration(modesYAML).cyclePaddingMode(forward: false)?.name).to(equal("27"))
                }

                it("does nothing without modes") {
                    let configuration = loadedConfiguration("layouts: [tall]")

                    expect(configuration.cyclePaddingMode(forward: true)).to(beNil())
                    expect(stateDefaults.string(forKey: UserConfiguration.activePaddingModeKey)).to(beNil())
                }
            }
        }
    }
}
