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
        // Like UserDefaults, read any number (YAML integers arrive as Int).
        return (storage[key] as? NSNumber)?.floatValue ?? 0
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
            func registrar(for yaml: [String: Any], commandKey: String = "test", defaults: [String: Any] = [:]) -> TestHotKeyRegistrar {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.configurationYAML = yaml
                configuration.configurationJSON = nil
                configuration.defaultConfiguration = JSON(defaults)
                configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])
                configuration.modifier4 = configuration.modifierFlagsForStrings(["option", "control", "shift", "command"])

                let registrar = TestHotKeyRegistrar()
                configuration.constructCommand(for: registrar, commandKey: commandKey, handler: {})
                return registrar
            }

            it("binds the key the configuration gives") {
                let registrar = registrar(for: ["test": ["mod": "mod4", "key": "0"]])

                expect(registrar.keyString).to(equal("0"))
                expect(registrar.modifiers).to(equal([.option, .control, .shift, .command]))
                expect(registrar.defaultsKey).to(equal("test"))
            }

            it("also reads JSON configurations") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.configurationYAML = nil
                configuration.configurationJSON = JSON(["test": ["mod": "mod1", "key": "1"]])
                configuration.modifier1 = configuration.modifierFlagsForStrings(["command"])
                let registrar = TestHotKeyRegistrar()

                configuration.constructCommand(for: registrar, commandKey: "test", handler: {})

                expect(registrar.keyString).to(equal("1"))
            }

            it("accepts a number as the key") {
                expect(registrar(for: ["test": ["mod": "mod1", "key": 1]]).keyString).to(equal("1"))
            }

            it("always replaces previously stored shortcuts") {
                expect(registrar(for: ["test": ["mod": "mod1", "key": "1"]]).override).to(beTrue())
                expect(registrar(for: [:]).override).to(beTrue())
            }

            it("leaves commands the configuration doesn't bind unbound, ignoring built-in defaults") {
                let registrar = registrar(for: ["mod1": ["command"]], defaults: ["test": ["mod": "mod1", "key": "2"]])

                expect(registrar.keyString).to(beNil())
                expect(registrar.modifiers).to(beNil())
                expect(registrar.handler).toNot(beNil())
            }

            it("leaves commands set to false unbound") {
                expect(registrar(for: ["test": false]).keyString).to(beNil())
            }

            it("leaves commands bound to <NONE> unbound") {
                expect(registrar(for: ["test": ["mod": "<NONE>", "key": "<NONE>"]]).keyString).to(beNil())
            }

            it("leaves malformed commands unbound without crashing") {
                expect(registrar(for: ["test": ["key": "2"]]).keyString).to(beNil())
                expect(registrar(for: ["test": ["mod": "mod7", "key": "2"]]).keyString).to(beNil())
                expect(registrar(for: ["test": "nonsense"]).keyString).to(beNil())
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

            context("float decision reasons") {
                let bundleIdentifiable = TestBundleIdentifiable()
                bundleIdentifiable.bundleIdentifier = "test.test.Test"

                it("names the listed application") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)

                    storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([FloatingBundle(id: "test.test.*", windowTitles: [])])

                    expect(configuration.floatDecision(for: bundleIdentifiable, title: "Main")).to(equal(.reliable(FloatDecision(float: .floating, reason: .listed(id: "test.test.*")))))

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)

                    expect(configuration.floatDecision(for: bundleIdentifiable, title: "Main")).to(equal(.reliable(FloatDecision(float: .notFloating, reason: .listed(id: "test.test.*")))))
                }

                it("names the matching title pattern") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)

                    storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([FloatingBundle(id: "test.test.Test", windowTitles: ["^Other$", "^Settings$"])])

                    let settingsReason = PlacementReason.titleMatched(pattern: "^Settings$", id: "test.test.Test")
                    expect(configuration.floatDecision(for: bundleIdentifiable, title: "Settings")).to(equal(.reliable(FloatDecision(float: .floating, reason: settingsReason))))
                    expect(configuration.floatDecision(for: bundleIdentifiable, title: "Main")).to(equal(.reliable(FloatDecision(float: .notFloating, reason: .titleNotMatched(id: "test.test.Test")))))
                    expect(configuration.floatDecision(for: bundleIdentifiable, title: nil)).to(equal(.unreliable(FloatDecision(float: .notFloating, reason: .titleNotMatched(id: "test.test.Test")))))
                    expect(configuration.floatDecision(for: bundleIdentifiable, title: "")).to(equal(.unreliable(FloatDecision(float: .notFloating, reason: .titleNotMatched(id: "test.test.Test")))))
                }

                it("says when the application isn't listed") {
                    let storage = TestConfigurationStorage()
                    let configuration = UserConfiguration(storage: storage)

                    storage.set(true, forKey: .floatingBundleIdentifiersIsBlacklist)
                    configuration.setFloatingBundles([FloatingBundle(id: "other.app", windowTitles: [])])

                    expect(configuration.floatDecision(for: bundleIdentifiable, title: "Main")).to(equal(.reliable(FloatDecision(float: .notFloating, reason: .notListed))))

                    storage.set(false, forKey: .floatingBundleIdentifiersIsBlacklist)

                    expect(configuration.floatDecision(for: bundleIdentifiable, title: "Main")).to(equal(.reliable(FloatDecision(float: .floating, reason: .notListed))))
                }
            }
        }

        describe("configuration file name") {
            it("names the file in the XDG directory after the configuration") {
                expect(UserConfiguration.xdgConfigurationFile(inDirectory: "/x/ametrine", name: "ametrine")).to(equal("/x/ametrine/ametrine.yml"))
                expect(UserConfiguration.xdgConfigurationFile(inDirectory: "/x/amethyst", name: "amethyst")).to(equal("/x/amethyst/amethyst.yml"))
            }
        }

        describe("window max count") {
            it("sets the limit, with 0 as unlimited") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                configuration.setWindowMaxCount(6)
                expect(configuration.windowMaxCount()).to(equal(6))

                configuration.setWindowMaxCount(0)
                expect(configuration.windowMaxCount()).to(beNil())
            }
        }

        describe("focus border") {
            it("is off by default, with a 5 pt accent glow and 12 pt corners") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                let appearance = configuration.focusBorderAppearance()

                expect(configuration.focusBorder()).to(beFalse())
                expect(appearance.style).to(equal(.glow))
                expect(appearance.width).to(equal(5))
                expect(appearance.radius).to(equal(12))
                expect(appearance.color).to(equal(.accent))
                expect(appearance.gradient).to(equal(FocusBorderAppearance.defaultGradient))
            }

            it("reads the configured values and falls back on unreadable ones") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set("solid", forKey: .focusBorderStyle)
                storage.set(Float(3), forKey: .focusBorderWidth)
                storage.set(Float(0), forKey: .focusBorderRadius)
                storage.set("#FF453A", forKey: .focusBorderColor)
                storage.set(["#000000", "#FFFFFF"], forKey: .focusBorderGradient)
                var appearance = configuration.focusBorderAppearance()
                expect(appearance.style).to(equal(.solid))
                expect(appearance.width).to(equal(3))
                expect(appearance.radius).to(equal(0))
                expect(appearance.color).to(equal(FocusBorderColor("#FF453A")))
                expect(appearance.gradient).to(equal([FocusBorderColor("#000000")!, FocusBorderColor("#FFFFFF")!]))

                storage.set("neon", forKey: .focusBorderStyle)
                storage.set("red", forKey: .focusBorderColor)
                storage.set(["#000000"], forKey: .focusBorderGradient)
                appearance = configuration.focusBorderAppearance()
                expect(appearance.style).to(equal(.glow))
                expect(appearance.color).to(equal(.accent))
                expect(appearance.gradient).to(equal(FocusBorderAppearance.defaultGradient))
            }

            it("toggles on and off and cycles the style") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())

                expect(configuration.toggleFocusBorder()).to(beTrue())
                expect(configuration.focusBorder()).to(beTrue())
                expect(configuration.toggleFocusBorder()).to(beFalse())

                expect(configuration.cycleFocusBorderStyle()).to(equal(.solid))
                expect(configuration.cycleFocusBorderStyle()).to(equal(.gradient))
                expect(configuration.cycleFocusBorderStyle()).to(equal(.glow))
                expect(configuration.focusBorderStyle()).to(equal(.glow))
            }
        }

        describe("main arrival position") {
            it("is last unless the configuration says first") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                expect(configuration.mainArrivalPosition()).to(equal(.last))

                storage.set("first", forKey: .mainArrivalPosition)
                expect(configuration.mainArrivalPosition()).to(equal(.first))

                storage.set(true, forKey: .mainArrivalPosition)
                expect(configuration.mainArrivalPosition()).to(equal(.last))

                storage.set("top", forKey: .mainArrivalPosition)
                expect(configuration.mainArrivalPosition()).to(equal(.last))
            }

            it("toggles between last and first") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())

                expect(configuration.toggleMainArrivalPosition()).to(equal(.first))
                expect(configuration.mainArrivalPosition()).to(equal(.first))
                expect(configuration.toggleMainArrivalPosition()).to(equal(.last))
                expect(configuration.mainArrivalPosition()).to(equal(.last))
            }
        }

        describe("layout names") {
            func loadedConfiguration(_ yaml: String) -> UserConfiguration {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())
                configuration.configurationYAML = try! Yams.load(yaml: yaml) as? [String: Any]
                configuration.configurationJSON = nil
                configuration.defaultConfiguration = JSON([String: Any]())
                configuration.loadConfiguration()
                return configuration
            }

            let yaml = """
            layout-names:
              tall-left: coding
              tall-right: "  coding (flipped)  "
              wide-top: ""
              3column-middle: 27
              row-top:
              not-a-layout: ignored
            """

            it("shows the configured name") {
                let configuration = loadedConfiguration(yaml)

                expect(configuration.layoutDisplayName(forKey: "tall-left", builtInName: "Tall Left")).to(equal("coding"))
                expect(configuration.layoutDisplayName(forKey: "tall-right", builtInName: "Tall Right")).to(equal("coding (flipped)"))
            }

            it("shows the built-in name for a layout without an entry") {
                let configuration = loadedConfiguration(yaml)

                expect(configuration.layoutDisplayName(forKey: "bsp", builtInName: "Binary Space Partitioning")).to(equal("Binary Space Partitioning"))
                expect(loadedConfiguration("layouts: [bsp]").layoutDisplayName(forKey: "bsp", builtInName: "BSP")).to(equal("BSP"))
            }

            it("shows the key when the name is empty, missing or not text") {
                let configuration = loadedConfiguration(yaml)

                expect(configuration.layoutDisplayName(forKey: "wide-top", builtInName: "Wide Top")).to(equal("wide-top"))
                expect(configuration.layoutDisplayName(forKey: "row-top", builtInName: "Row Top")).to(equal("row-top"))
                expect(configuration.layoutDisplayName(forKey: "3column-middle", builtInName: "3Column Middle")).to(equal("3column-middle"))
            }

            it("ignores layout-names that isn't a map") {
                let configuration = loadedConfiguration("layout-names: [coding]")

                expect(configuration.layoutDisplayName(forKey: "tall-left", builtInName: "Tall Left")).to(equal("Tall Left"))
            }
        }

        describe("window overflow") {
            it("minimises unless the configuration says float") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                expect(configuration.windowOverflow()).to(equal(.minimize))

                storage.set("float", forKey: .windowOverflow)
                expect(configuration.windowOverflow()).to(equal(.float))

                storage.set("hide", forKey: .windowOverflow)
                expect(configuration.windowOverflow()).to(equal(.minimize))
            }

            it("toggles between minimize and float") {
                let configuration = UserConfiguration(storage: TestConfigurationStorage())

                expect(configuration.toggleWindowOverflow()).to(equal(.float))
                expect(configuration.windowOverflow()).to(equal(.float))
                expect(configuration.toggleWindowOverflow()).to(equal(.minimize))
            }

            it("toggles the size only when a size is configured") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                expect(configuration.windowOverflowFixedSize()).to(beNil())
                expect(configuration.toggleWindowOverflowSize()).to(equal(.reasonable))

                storage.set(Float(1600), forKey: .windowOverflowWidth)
                storage.set(Float(1100), forKey: .windowOverflowHeight)
                expect(configuration.windowOverflowFixedSize()).to(equal(CGSize(width: 1600, height: 1100)))
                expect(configuration.toggleWindowOverflowSize()).to(equal(.fixed))
                expect(configuration.toggleWindowOverflowSize()).to(equal(.reasonable))
            }

            it("reads the reasonable share as percentages, falling back to 60% × 70%") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                expect(configuration.windowOverflowReasonableShare()).to(equal(CGSize(width: 0.6, height: 0.7)))

                storage.set(Float(50), forKey: .windowOverflowReasonableWidth)
                storage.set(Float(80), forKey: .windowOverflowReasonableHeight)
                expect(configuration.windowOverflowReasonableShare()).to(equal(CGSize(width: 0.5, height: 0.8)))

                storage.set(Float(0), forKey: .windowOverflowReasonableWidth)
                storage.set(Float(120), forKey: .windowOverflowReasonableHeight)
                expect(configuration.windowOverflowReasonableShare()).to(equal(CGSize(width: 0.6, height: 0.7)))
            }

            it("reads the size mode from the configuration") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                storage.set("fixed", forKey: .windowOverflowSize)
                expect(configuration.windowOverflowSize()).to(equal(.reasonable))

                storage.set(Float(1600), forKey: .windowOverflowWidth)
                storage.set(Float(1100), forKey: .windowOverflowHeight)
                expect(configuration.windowOverflowSize()).to(equal(.fixed))
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

            it("with a configuration file, keys it leaves out don't keep earlier values") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)
                storage.set(["wide"], forKey: .layouts)
                storage.set(Float(540), forKey: .screenPaddingTop)

                configuration.configurationYAML = ["mod1": ["option"]]
                configuration.configurationJSON = nil
                configuration.defaultConfiguration = JSON(["layouts": ["tall"]])
                configuration.loadConfiguration()

                expect(configuration.layoutKeys()).to(equal(["tall"]))
                expect(storage.object(forKey: .screenPaddingTop)).to(beNil())
            }

            it("reads main-arrival-position from a configuration file") {
                let storage = TestConfigurationStorage()
                let configuration = UserConfiguration(storage: storage)

                configuration.configurationYAML = ["main-arrival-position": "first"]
                configuration.configurationJSON = nil
                configuration.defaultConfiguration = JSON(["main-arrival-position": "last"])
                configuration.loadConfiguration()

                expect(configuration.mainArrivalPosition()).to(equal(.first))
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

        describe("floating secondary windows") {
            func configuration(_ patterns: [String]?) -> UserConfiguration {
                let storage = TestConfigurationStorage()
                if let patterns = patterns {
                    storage.set(patterns, forKey: .floatingSecondaryWindows)
                }
                return UserConfiguration(storage: storage)
            }

            func application(_ bundleIdentifier: String?) -> TestBundleIdentifiable {
                let application = TestBundleIdentifiable()
                application.bundleIdentifier = bundleIdentifier
                return application
            }

            it("lists no applications by default") {
                expect(configuration(nil).floatsSecondaryWindows(of: application("md.obsidian"))).to(beFalse())
            }

            it("matches exact ids") {
                let configuration = configuration(["md.obsidian"])

                expect(configuration.floatsSecondaryWindows(of: application("md.obsidian"))).to(beTrue())
                expect(configuration.floatsSecondaryWindows(of: application("md.obsidian.helper"))).to(beFalse())
                expect(configuration.floatsSecondaryWindows(of: application(nil))).to(beFalse())
            }

            it("matches globs like the floating list") {
                let configuration = configuration(["com.jetbrains.*"])

                expect(configuration.floatsSecondaryWindows(of: application("com.jetbrains.intellij"))).to(beTrue())
                expect(configuration.floatsSecondaryWindows(of: application("com.jetbrainsX"))).to(beFalse())
            }

            it("is independent of the floating list") {
                let storage = TestConfigurationStorage()
                storage.set(["md.obsidian"], forKey: .floatingBundleIdentifiers)
                let configuration = UserConfiguration(storage: storage)

                expect(configuration.floatsSecondaryWindows(of: application("md.obsidian"))).to(beFalse())
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

            let spaceA = "SPACE-A"
            let spaceB = "SPACE-B"

            func paddings(_ configuration: UserConfiguration, on spaceUUID: String? = spaceA) -> [CGFloat] {
                return [
                    configuration.screenPaddingTop(forSpaceUUID: spaceUUID),
                    configuration.screenPaddingBottom(forSpaceUUID: spaceUUID),
                    configuration.screenPaddingLeft(forSpaceUUID: spaceUUID),
                    configuration.screenPaddingRight(forSpaceUUID: spaceUUID)
                ]
            }

            let plainPaddingsYAML = """

            screen-padding-top: 10
            screen-padding-bottom: 20
            screen-padding-left: 30
            screen-padding-right: 40
            """

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
                    let configuration = loadedConfiguration("layouts: [tall]" + plainPaddingsYAML)

                    expect(configuration.activePaddingMode(forSpaceUUID: spaceA)).to(beNil())
                    expect(paddings(configuration)).to(equal([10, 20, 30, 40]))
                }

                it("uses the plain screen paddings while no mode is selected") {
                    let configuration = loadedConfiguration(modesYAML + plainPaddingsYAML)

                    expect(paddings(configuration)).to(equal([10, 20, 30, 40]))
                }

                it("uses the active mode's values") {
                    let configuration = loadedConfiguration(modesYAML + plainPaddingsYAML)

                    configuration.selectPaddingMode(named: "27", forSpaceUUID: spaceA)

                    expect(paddings(configuration)).to(equal([720, 0, 640, 640]))
                }

                it("falls back to the plain screen paddings for an unknown active name") {
                    stateDefaults.set([spaceA: "gone"], forKey: UserConfiguration.paddingModeBySpaceKey)
                    let configuration = loadedConfiguration(modesYAML + plainPaddingsYAML)

                    expect(configuration.activePaddingMode(forSpaceUUID: spaceA)).to(beNil())
                    expect(paddings(configuration)).to(equal([10, 20, 30, 40]))
                }
            }

            describe("active mode") {
                it("starts with padding-mode from the configuration") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    expect(configuration.activePaddingMode(forSpaceUUID: spaceA)?.name).to(equal("wide"))
                }

                it("accepts a bare number for padding-mode") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: 27")

                    expect(configuration.activePaddingMode(forSpaceUUID: spaceA)?.name).to(equal("27"))
                }

                it("prefers the selected mode over padding-mode, also after reloading the configuration") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    configuration.selectPaddingMode(named: "full", forSpaceUUID: spaceA)
                    configuration.loadConfiguration()

                    expect(configuration.activePaddingMode(forSpaceUUID: spaceA)?.name).to(equal("full"))
                }

                it("survives a restart") {
                    loadedConfiguration(modesYAML).selectPaddingMode(named: "27", forSpaceUUID: spaceA)

                    let relaunched = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    expect(relaunched.activePaddingMode(forSpaceUUID: spaceA)?.name).to(equal("27"))
                }

                it("ignores selecting an unknown name") {
                    let configuration = loadedConfiguration(modesYAML)
                    configuration.selectPaddingMode(named: "wide", forSpaceUUID: spaceA)

                    expect(configuration.selectPaddingMode(named: "nope", forSpaceUUID: spaceA)).to(beNil())
                    expect(configuration.activePaddingMode(forSpaceUUID: spaceA)?.name).to(equal("wide"))
                }
            }

            describe("per Space") {
                it("keeps a selection to its own Space") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    configuration.selectPaddingMode(named: "27", forSpaceUUID: spaceA)
                    configuration.selectPaddingMode(named: "full", forSpaceUUID: spaceB)

                    expect(configuration.activePaddingMode(forSpaceUUID: spaceA)?.name).to(equal("27"))
                    expect(configuration.activePaddingMode(forSpaceUUID: spaceB)?.name).to(equal("full"))
                    expect(configuration.activePaddingMode(forSpaceUUID: "SPACE-NEW")?.name).to(equal("wide"))
                }

                it("gives each screen the padding of its own Space") {
                    let configuration = loadedConfiguration(modesYAML + plainPaddingsYAML)

                    configuration.selectPaddingMode(named: "27", forSpaceUUID: spaceA)

                    expect(paddings(configuration, on: spaceA)).to(equal([720, 0, 640, 640]))
                    expect(paddings(configuration, on: spaceB)).to(equal([10, 20, 30, 40]))
                }

                it("uses padding-mode without a Space and stores nothing") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    expect(configuration.activePaddingMode(forSpaceUUID: nil)?.name).to(equal("wide"))
                    expect(configuration.selectPaddingMode(named: "27", forSpaceUUID: nil)?.name).to(equal("27"))
                    expect(stateDefaults.dictionary(forKey: UserConfiguration.paddingModeBySpaceKey)).to(beNil())
                }

                it("drops the single mode stored before modes were per Space") {
                    stateDefaults.set("27", forKey: UserConfiguration.legacyActivePaddingModeKey)

                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    expect(configuration.activePaddingMode(forSpaceUUID: spaceA)?.name).to(equal("wide"))
                    expect(stateDefaults.string(forKey: UserConfiguration.legacyActivePaddingModeKey)).to(beNil())
                }
            }

            describe("cycling") {
                it("goes forward in order and wraps around") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    let names = (0..<3).compactMap { _ in configuration.cyclePaddingMode(forward: true, forSpaceUUID: spaceA)?.name }

                    expect(names).to(equal(["27", "full", "wide"]))
                }

                it("goes backward and wraps around") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")

                    let names = (0..<3).compactMap { _ in configuration.cyclePaddingMode(forward: false, forSpaceUUID: spaceA)?.name }

                    expect(names).to(equal(["full", "27", "wide"]))
                }

                it("starts at the first or last mode when none is active") {
                    expect(loadedConfiguration(modesYAML).cyclePaddingMode(forward: true, forSpaceUUID: spaceA)?.name).to(equal("full"))
                    expect(loadedConfiguration(modesYAML).cyclePaddingMode(forward: false, forSpaceUUID: spaceB)?.name).to(equal("27"))
                }

                it("cycles from the Space's own mode and leaves other Spaces alone") {
                    let configuration = loadedConfiguration(modesYAML + "\npadding-mode: wide")
                    configuration.selectPaddingMode(named: "full", forSpaceUUID: spaceA)

                    expect(configuration.cyclePaddingMode(forward: true, forSpaceUUID: spaceA)?.name).to(equal("wide"))
                    expect(configuration.activePaddingMode(forSpaceUUID: spaceB)?.name).to(equal("wide"))
                    expect(configuration.cyclePaddingMode(forward: true, forSpaceUUID: spaceB)?.name).to(equal("27"))
                    expect(configuration.activePaddingMode(forSpaceUUID: spaceA)?.name).to(equal("wide"))
                }

                it("does nothing without modes") {
                    let configuration = loadedConfiguration("layouts: [tall]")

                    expect(configuration.cyclePaddingMode(forward: true, forSpaceUUID: spaceA)).to(beNil())
                    expect(stateDefaults.dictionary(forKey: UserConfiguration.paddingModeBySpaceKey)).to(beNil())
                }
            }
        }
    }
}
