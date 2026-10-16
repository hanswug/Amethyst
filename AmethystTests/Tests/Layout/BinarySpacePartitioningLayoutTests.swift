//
//  BinarySpacePartitioningLayoutTests.swift
//  Amethyst
//
//  Created by Ian Ynda-Hummel on 5/29/16.
//  Copyright © 2016 Ian Ynda-Hummel. All rights reserved.
//

@testable import Amethyst
import Cocoa
import Nimble
import Quick

class BinarySpacePartitioningLayoutTests: QuickSpec {
    override func spec() {
        describe("TreeNode") {
            describe("finding") {
                it("finds a node that exists") {
                    let rootNode = TreeNode<TestWindow>()
                    let node1 = TreeNode<TestWindow>()
                    let node2 = TreeNode<TestWindow>()
                    let node3 = TreeNode<TestWindow>()
                    let node4 = TreeNode<TestWindow>()

                    node1.parent = rootNode
                    node1.left = node2
                    node1.right = node3

                    node2.windowID = "0"
                    node2.parent = node1

                    node3.windowID = "1"
                    node3.parent = node1

                    node4.windowID = "2"
                    node4.parent = rootNode

                    rootNode.left = node1
                    rootNode.right = node4

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.findWindowID("0")).to(equal(node2))
                    expect(rootNode.findWindowID("1")).to(equal(node3))
                    expect(rootNode.findWindowID("2")).to(equal(node4))
                }

                it("does not find a node that does not exist") {
                    let rootNode = TreeNode<TestWindow>()
                    let node1 = TreeNode<TestWindow>()
                    let node2 = TreeNode<TestWindow>()

                    node1.windowID = "0"
                    node1.parent = rootNode
                    node2.windowID = "1"
                    node2.parent = rootNode

                    rootNode.left = node1
                    rootNode.right = node2

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.findWindowID("2")).to(beNil())
                }
            }

            describe("traversing") {
                it("generates an empty list for an empty tree") {
                    let rootNode = TreeNode<TestWindow>()
                    expect(rootNode.orderedWindowIDs()).to(equal([]))
                }

                it("generates a correctly ordered list") {
                    let rootNode = TreeNode<TestWindow>()
                    let node1 = TreeNode<TestWindow>()
                    let node2 = TreeNode<TestWindow>()
                    let node3 = TreeNode<TestWindow>()
                    let node4 = TreeNode<TestWindow>()

                    node1.parent = rootNode
                    node1.left = node2
                    node1.right = node3

                    node2.windowID = "0"
                    node2.parent = node1

                    node3.windowID = "1"
                    node3.parent = node1

                    node4.windowID = "2"
                    node4.parent = rootNode

                    rootNode.left = node4
                    rootNode.right = node1

                    let orderedList = rootNode.orderedWindowIDs()

                    expect(orderedList).to(equal(["2", "0", "1"]))
                }
            }

            describe("insertion") {
                it("inserts at end") {
                    let rootNode = TreeNode<TestWindow>()
                    let node1 = TreeNode<TestWindow>()
                    let node2 = TreeNode<TestWindow>()

                    node1.windowID = "0"
                    node1.parent = rootNode
                    node2.windowID = "1"
                    node2.parent = rootNode

                    rootNode.left = node1
                    rootNode.right = node2

                    expect(rootNode.treeIsValid()).to(beTrue())

                    rootNode.insertWindowIDAtEnd("2")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.right?.left?.windowID).to(equal("1"))
                    expect(rootNode.right?.right?.windowID).to(equal("2"))

                    rootNode.insertWindowIDAtEnd("3")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.right?.left?.windowID).to(equal("1"))
                    expect(rootNode.right?.right?.left?.windowID).to(equal("2"))
                    expect(rootNode.right?.right?.right?.windowID).to(equal("3"))
                }

                it("inserts at the insertion point") {
                    let rootNode = TreeNode<TestWindow>()
                    let node1 = TreeNode<TestWindow>()
                    let node2 = TreeNode<TestWindow>()

                    node1.windowID = "0"
                    node1.parent = rootNode
                    node2.windowID = "1"
                    node2.parent = rootNode

                    rootNode.left = node1
                    rootNode.right = node2

                    expect(rootNode.treeIsValid()).to(beTrue())

                    rootNode.insertWindowID("2", atPoint: "0")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.left?.windowID).to(beNil())
                    expect(rootNode.left?.left?.windowID).to(equal("0"))
                    expect(rootNode.left?.right?.windowID).to(equal("2"))

                    rootNode.insertWindowID("3", atPoint: "2")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.left?.windowID).to(beNil())
                    expect(rootNode.left?.right?.windowID).to(beNil())
                    expect(rootNode.left?.right?.left?.windowID).to(equal("2"))
                    expect(rootNode.left?.right?.right?.windowID).to(equal("3"))

                    rootNode.insertWindowID("4", atPoint: "0")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.left?.windowID).to(beNil())
                    expect(rootNode.left?.left?.windowID).to(beNil())
                    expect(rootNode.left?.left?.left?.windowID).to(equal("0"))
                    expect(rootNode.left?.left?.right?.windowID).to(equal("4"))
                }

                it("inserts") {
                    let rootNode = TreeNode<TestWindow>()
                    let node1 = TreeNode<TestWindow>()
                    let node2 = TreeNode<TestWindow>()

                    node1.windowID = "0"
                    node1.parent = rootNode
                    node2.windowID = "1"
                    node2.parent = rootNode

                    rootNode.left = node1
                    rootNode.right = node2

                    expect(rootNode.treeIsValid()).to(beTrue())

                    node1.insertWindowID("2")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.left?.windowID).to(beNil())
                    expect(rootNode.left?.left?.windowID).to(equal("0"))
                    expect(rootNode.left?.right?.windowID).to(equal("2"))
                }

                it("sets root value when the tree is empty") {
                    let rootNode = TreeNode<TestWindow>()

                    rootNode.insertWindowIDAtEnd("0")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.windowID).to(equal("0"))
                }

                it("clears root value when inserting value after first one") {
                    let rootNode = TreeNode<TestWindow>()

                    rootNode.insertWindowIDAtEnd("0")
                    rootNode.insertWindowIDAtEnd("1")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.left).toNot(beNil())
                    expect(rootNode.right).toNot(beNil())
                    expect(rootNode.windowID).to(beNil())
                }
            }

            describe("removing") {
                it("removes from a shallow tree") {
                    let rootNode = TreeNode<TestWindow>()
                    let node1 = TreeNode<TestWindow>()
                    let node2 = TreeNode<TestWindow>()
                    let node3 = TreeNode<TestWindow>()
                    let node4 = TreeNode<TestWindow>()

                    node1.parent = rootNode
                    node1.left = node2
                    node1.right = node3

                    node2.windowID = "0"
                    node2.parent = node1

                    node3.windowID = "1"
                    node3.parent = node1

                    node4.windowID = "2"
                    node4.parent = rootNode

                    rootNode.left = node1
                    rootNode.right = node4

                    expect(rootNode.treeIsValid()).to(beTrue())

                    rootNode.removeWindowID("1")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.findWindowID("1")).to(beNil())
                    expect(rootNode.left?.windowID).to(equal("0"))

                    rootNode.removeWindowID("2")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.findWindowID("2")).to(beNil())
                    expect(rootNode.windowID).to(equal("0"))
                }

                it("removes from a deep tree") {
                    let rootNode = TreeNode<TestWindow>()

                    (0..<10).forEach { rootNode.insertWindowIDAtEnd("\($0)") }

                    expect(rootNode.treeIsValid()).to(beTrue())

                    rootNode.removeWindowID("5")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.findWindowID("5")).to(beNil())
                }

                it("keeps the sibling subtree when removing a child of the root") {
                    let rootNode = TreeNode<TestWindow>()

                    (0..<4).forEach { rootNode.insertWindowIDAtEnd("\($0)") }

                    rootNode.removeWindowID("0")

                    expect(rootNode.treeIsValid()).to(beTrue())
                    expect(rootNode.orderedWindowIDs()).to(equal(["1", "2", "3"]))
                    expect(rootNode.left?.windowID).to(equal("1"))
                    expect(rootNode.right?.left?.windowID).to(equal("2"))
                    expect(rootNode.right?.right?.windowID).to(equal("3"))
                }

                it("empties a tree holding one window") {
                    let rootNode = TreeNode<TestWindow>()

                    rootNode.insertWindowIDAtEnd("0")
                    rootNode.removeWindowID("0")

                    expect(rootNode.windowID).to(beNil())
                    expect(rootNode.orderedWindowIDs()).to(equal([]))
                }
            }

            describe("validitity") {
                it("is invalid when a node has children and an id at the same time") {
                    let node = TreeNode<TestWindow>()
                    let node2 = TreeNode<TestWindow>()
                    let node3 = TreeNode<TestWindow>()

                    node.windowID = "0"
                    node2.windowID = "1"
                    node3.windowID = "2"

                    expect(node.valid).to(beTrue())

                    node.left = node2
                    node.right = node3

                    expect(node.valid).to(beFalse())
                }
            }

            it("deep compares") {
                let treeGenerator: () -> TreeNode<TestWindow> = {
                    let rootNode = TreeNode<TestWindow>()
                    let node1 = TreeNode<TestWindow>()
                    let node2 = TreeNode<TestWindow>()
                    let node3 = TreeNode<TestWindow>()
                    let node4 = TreeNode<TestWindow>()

                    node1.parent = rootNode
                    node1.left = node2
                    node1.right = node3

                    node2.windowID = "0"
                    node2.parent = node1

                    node3.windowID = "1"
                    node3.parent = node1

                    node4.windowID = "2"
                    node4.parent = rootNode

                    rootNode.left = node4
                    rootNode.right = node1

                    return rootNode
                }
                let tree1 = treeGenerator()
                let tree2 = treeGenerator()
                let tree3 = treeGenerator()

                tree3.right?.right?.windowID = "5"

                expect(tree1 == tree2).to(beTrue())
                expect(tree1 == tree3).to(beFalse())
            }
        }

        describe("layout") {
            it("splits into binary partitions") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )

                let layout = BinarySpacePartitioningLayout<TestWindow>()
                windows.forEach { layout.updateWithChange(.add(window: $0)) }

                let assignments = layout.frameAssignments(windowSet, on: screen)!
                assignments.verify(frames: [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000),
                    CGRect(x: 1000, y: 0, width: 1000, height: 500),
                    CGRect(x: 1000, y: 500, width: 500, height: 500),
                    CGRect(x: 1500, y: 500, width: 500, height: 500)
                ])
            }

            it("handles non-origin screens") {
                let screen = TestScreen(frame: CGRect(x: 100, y: 100, width: 2000, height: 1000))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )

                let layout = BinarySpacePartitioningLayout<TestWindow>()
                windows.forEach { layout.updateWithChange(.add(window: $0)) }

                let assignments = layout.frameAssignments(windowSet, on: screen)!
                assignments.verify(frames: [
                    CGRect(x: 100, y: 100, width: 1000, height: 1000),
                    CGRect(x: 1100, y: 100, width: 1000, height: 500),
                    CGRect(x: 1100, y: 600, width: 500, height: 500),
                    CGRect(x: 1600, y: 600, width: 500, height: 500)
                ])
            }

            describe("adding windows") {
                it("partitions the focused frame") {
                    let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                    TestScreen.availableScreens = [screen]

                    let windows = [
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!
                    ]

                    var layoutWindows = windows.map {
                        LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: $0.isFocused())
                    }
                    var windowSet = WindowSet<TestWindow>(
                        windows: layoutWindows.dropLast(),
                        isWindowWithIDActive: { _ in return true },
                        isWindowWithIDFloating: { _ in return false },
                        windowForID: { id in return windows.first { $0.id() == id } }
                    )

                    let layout = BinarySpacePartitioningLayout<TestWindow>()
                    windows.dropLast().forEach { layout.updateWithChange(.add(window: $0)) }

                    var assignments = layout.frameAssignments(windowSet, on: screen)!
                    var expectedFrames = [
                        CGRect(x: 0, y: 0, width: 1000, height: 1000),
                        CGRect(x: 1000, y: 0, width: 1000, height: 500),
                        CGRect(x: 1000, y: 500, width: 1000, height: 500)
                    ]

                    expect(assignments.frames()).to(equal(expectedFrames), description: assignments.description(withExpectedFrames: expectedFrames))

                    windows[1].isFocusedValue = true
                    layoutWindows[1] = LayoutWindow<TestWindow>(id: windows[1].id(), frame: windows[1].frame(), isFocused: windows[1].isFocused())
                    layout.updateWithChange(.focusChanged(window: windows[1]))
                    layout.updateWithChange(.add(window: windows.last!))

                    windowSet = WindowSet<TestWindow>(
                        windows: layoutWindows,
                        isWindowWithIDActive: { _ in return true },
                        isWindowWithIDFloating: { _ in return false },
                        windowForID: { id in return windows.first { $0.id() == id } }
                    )

                    assignments = layout.frameAssignments(windowSet, on: screen)!.sorted()
                    expectedFrames = [
                        CGRect(x: 0, y: 0, width: 1000, height: 1000),
                        CGRect(x: 1000, y: 0, width: 500, height: 500),
                        CGRect(x: 1500, y: 0, width: 500, height: 500),
                        CGRect(x: 1000, y: 500, width: 1000, height: 500)
                    ]

                    expect(assignments.frames()).to(equal(expectedFrames), description: assignments.description(withExpectedFrames: expectedFrames))
                }

                it("partitions the last frame if nothing is focused") {
                    let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                    TestScreen.availableScreens = [screen]

                    let windows = [
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!
                    ]

                    let layoutWindows = windows.map {
                        LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: $0.isFocused())
                    }
                    var windowSet = WindowSet<TestWindow>(
                        windows: layoutWindows.dropLast(),
                        isWindowWithIDActive: { _ in return true },
                        isWindowWithIDFloating: { _ in return false },
                        windowForID: { id in return windows.first { $0.id() == id } }
                    )

                    let layout = BinarySpacePartitioningLayout<TestWindow>()
                    windows.dropLast().forEach { layout.updateWithChange(.add(window: $0)) }

                    var assignments = layout.frameAssignments(windowSet, on: screen)!
                    var expectedFrames = [
                        CGRect(x: 0, y: 0, width: 1000, height: 1000),
                        CGRect(x: 1000, y: 0, width: 1000, height: 500),
                        CGRect(x: 1000, y: 500, width: 1000, height: 500)
                    ]

                    expect(assignments.frames()).to(equal(expectedFrames), description: assignments.description(withExpectedFrames: expectedFrames))

                    layout.updateWithChange(.add(window: windows.last!))

                    windowSet = WindowSet<TestWindow>(
                        windows: layoutWindows,
                        isWindowWithIDActive: { _ in return true },
                        isWindowWithIDFloating: { _ in return false },
                        windowForID: { id in return windows.first { $0.id() == id } }
                    )

                    assignments = layout.frameAssignments(windowSet, on: screen)!.sorted()
                    expectedFrames = [
                        CGRect(x: 0, y: 0, width: 1000, height: 1000),
                        CGRect(x: 1000, y: 0, width: 1000, height: 500),
                        CGRect(x: 1000, y: 500, width: 500, height: 500),
                        CGRect(x: 1500, y: 500, width: 500, height: 500)
                    ]

                    expect(assignments.frames()).to(equal(expectedFrames), description: assignments.description(withExpectedFrames: expectedFrames))
                }
            }

            describe("removing windows") {
                it("expands the sibling") {
                    let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                    TestScreen.availableScreens = [screen]

                    let windows = [
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!
                    ]
                    let layoutWindows = windows.map {
                        LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                    }
                    let windowSet = WindowSet<TestWindow>(
                        windows: layoutWindows,
                        isWindowWithIDActive: { _ in return true },
                        isWindowWithIDFloating: { _ in return false },
                        windowForID: { id in return windows.first { $0.id() == id } }
                    )

                    let layout = BinarySpacePartitioningLayout<TestWindow>()
                    windows.forEach { layout.updateWithChange(.add(window: $0)) }

                    var assignments = layout.frameAssignments(windowSet, on: screen)!
                    var expectedFrames = [
                        CGRect(x: 0, y: 0, width: 1000, height: 1000),
                        CGRect(x: 1000, y: 0, width: 1000, height: 500),
                        CGRect(x: 1000, y: 500, width: 500, height: 500),
                        CGRect(x: 1500, y: 500, width: 500, height: 500)
                    ]
                    expect(assignments.frames()).to(equal(expectedFrames), description: assignments.description(withExpectedFrames: expectedFrames))

                    layout.updateWithChange(.remove(window: windows[1]))

                    let remainingWindowSet = WindowSet<TestWindow>(
                        windows: layoutWindows.filter { $0.id != windows[1].id() },
                        isWindowWithIDActive: { _ in return true },
                        isWindowWithIDFloating: { _ in return false },
                        windowForID: { id in return windows.first { $0.id() == id } }
                    )
                    assignments = layout.frameAssignments(remainingWindowSet, on: screen)!
                    expectedFrames = [
                        CGRect(x: 0, y: 0, width: 1000, height: 1000),
                        CGRect(x: 1000, y: 0, width: 1000, height: 500),
                        CGRect(x: 1000, y: 500, width: 1000, height: 500)
                    ]
                    expect(assignments.frames()).to(equal(expectedFrames), description: assignments.description(withExpectedFrames: expectedFrames))
                }
            }

            it("constructs an initial tree if necessary") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let windows = [
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!,
                    TestWindow(element: nil)!
                ]
                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )

                let layout = BinarySpacePartitioningLayout<TestWindow>()

                let assignments = layout.frameAssignments(windowSet, on: screen)!
                let expectedFrames = [
                    CGRect(x: 0, y: 0, width: 1000, height: 1000),
                    CGRect(x: 1000, y: 0, width: 1000, height: 500),
                    CGRect(x: 1000, y: 500, width: 500, height: 500),
                    CGRect(x: 1500, y: 500, width: 500, height: 500)
                ]
                expect(assignments.frames()).to(equal(expectedFrames), description: assignments.description(withExpectedFrames: expectedFrames))
            }

            describe("syncing the tree with the windows") {
                it("gives the whole screen to the only window left") {
                    let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                    TestScreen.availableScreens = [screen]

                    let windows = [
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!
                    ]
                    let lastWindow = windows[3]
                    let windowSet = WindowSet<TestWindow>(
                        windows: [LayoutWindow<TestWindow>(id: lastWindow.id(), frame: lastWindow.frame(), isFocused: false)],
                        isWindowWithIDActive: { _ in return true },
                        isWindowWithIDFloating: { _ in return false },
                        windowForID: { id in return windows.first { $0.id() == id } }
                    )

                    // The other three never sent a remove event, e.g. their app was hidden.
                    let layout = BinarySpacePartitioningLayout<TestWindow>()
                    windows.forEach { layout.updateWithChange(.add(window: $0)) }

                    let assignments = layout.frameAssignments(windowSet, on: screen)!
                    let expectedFrames = [CGRect(x: 0, y: 0, width: 2000, height: 1000)]
                    expect(assignments.frames()).to(equal(expectedFrames), description: assignments.description(withExpectedFrames: expectedFrames))
                }

                it("splits the window focused at the last layout") {
                    let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                    TestScreen.availableScreens = [screen]

                    let windows = [
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!
                    ]
                    let layout = BinarySpacePartitioningLayout<TestWindow>()
                    layout.updateWithChange(.add(window: windows[0]))
                    layout.updateWithChange(.add(window: windows[1]))
                    layout.updateWithChange(.focusChanged(window: windows[1]))

                    // The left window got focus by clicking it in another app, which sends no focus event.
                    let focusedLeftWindowSet = WindowSet<TestWindow>(
                        windows: windows.dropLast().map {
                            LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: $0 == windows[0])
                        },
                        isWindowWithIDActive: { _ in return true },
                        isWindowWithIDFloating: { _ in return false },
                        windowForID: { id in return windows.first { $0.id() == id } }
                    )
                    _ = layout.frameAssignments(focusedLeftWindowSet, on: screen)

                    layout.updateWithChange(.add(window: windows[2]))

                    let windowSet = WindowSet<TestWindow>(
                        windows: windows.map { LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false) },
                        isWindowWithIDActive: { _ in return true },
                        isWindowWithIDFloating: { _ in return false },
                        windowForID: { id in return windows.first { $0.id() == id } }
                    )
                    let assignments = layout.frameAssignments(windowSet, on: screen)!
                    let expectedFrames = [
                        CGRect(x: 1000, y: 0, width: 1000, height: 1000),
                        CGRect(x: 0, y: 0, width: 1000, height: 500),
                        CGRect(x: 0, y: 500, width: 1000, height: 500)
                    ]
                    expect(assignments.frames()).to(equal(expectedFrames), description: assignments.description(withExpectedFrames: expectedFrames))
                }

                it("lays out a window the tree never heard of") {
                    let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                    TestScreen.availableScreens = [screen]

                    let windows = [
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!,
                        TestWindow(element: nil)!
                    ]
                    let layoutWindows = windows.map {
                        LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                    }
                    let windowSet = WindowSet<TestWindow>(
                        windows: layoutWindows,
                        isWindowWithIDActive: { _ in return true },
                        isWindowWithIDFloating: { _ in return false },
                        windowForID: { id in return windows.first { $0.id() == id } }
                    )

                    // The third window's add event never arrived, e.g. it was opened on another Space.
                    let layout = BinarySpacePartitioningLayout<TestWindow>()
                    windows.dropLast().forEach { layout.updateWithChange(.add(window: $0)) }

                    let assignments = layout.frameAssignments(windowSet, on: screen)!
                    let expectedFrames = [
                        CGRect(x: 0, y: 0, width: 1000, height: 1000),
                        CGRect(x: 1000, y: 0, width: 1000, height: 500),
                        CGRect(x: 1000, y: 500, width: 1000, height: 500)
                    ]
                    expect(assignments.frames()).to(equal(expectedFrames), description: assignments.description(withExpectedFrames: expectedFrames))
                }
            }
        }

        describe("warp") {
            it("leaves its tile and splits the neighbour's on the side it came from") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]
                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!, TestWindow(element: nil)!]
                let layout = BinarySpacePartitioningLayout<TestWindow>()
                windows.forEach { layout.updateWithChange(.add(window: $0)) }

                // a on the left; b above c on the right. a warps east onto b: it came from the west, so it takes the
                // first half of b's tile, which splits top/bottom.
                expect(layout.warp(windows[0].id(), onto: windows[1].id(), toward: .east)).to(beTrue())

                let windowSet = WindowSet<TestWindow>(
                    windows: windows.map { LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false) },
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let frames = Dictionary(uniqueKeysWithValues: layout.frameAssignments(windowSet, on: screen)!.map {
                    ($0.frameAssignment.window.id, $0.frameAssignment.frame)
                })
                expect(frames[windows[0].id()]).to(equal(CGRect(x: 0, y: 0, width: 1000, height: 500)))
                expect(frames[windows[1].id()]).to(equal(CGRect(x: 0, y: 500, width: 1000, height: 500)))
                expect(frames[windows[2].id()]).to(equal(CGRect(x: 1000, y: 0, width: 1000, height: 1000)))
            }

            it("takes the half it was dropped on, by mouse") {
                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]
                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!, TestWindow(element: nil)!]
                let layout = BinarySpacePartitioningLayout<TestWindow>()
                windows.forEach { layout.updateWithChange(.add(window: $0)) }

                // As above, but a is dropped on the second half of b's tile: a below b.
                expect(layout.warp(windows[0].id(), onto: windows[1].id(), first: false)).to(beTrue())

                let windowSet = WindowSet<TestWindow>(
                    windows: windows.map { LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false) },
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )
                let frames = Dictionary(uniqueKeysWithValues: layout.frameAssignments(windowSet, on: screen)!.map {
                    ($0.frameAssignment.window.id, $0.frameAssignment.frame)
                })
                expect(frames[windows[0].id()]).to(equal(CGRect(x: 0, y: 500, width: 1000, height: 500)))
                expect(frames[windows[1].id()]).to(equal(CGRect(x: 0, y: 0, width: 1000, height: 500)))
                expect(frames[windows[2].id()]).to(equal(CGRect(x: 1000, y: 0, width: 1000, height: 1000)))
            }

            it("does nothing for a window that isn't in the tree") {
                let layout = BinarySpacePartitioningLayout<TestWindow>()
                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!]
                layout.updateWithChange(.add(window: windows[0]))
                expect(layout.warp(windows[1].id(), onto: windows[0].id(), toward: .west)).to(beFalse())
            }
        }

        describe("coding") {
            it("encodes and decodes") {
                let layout = BinarySpacePartitioningLayout<TestWindow>()
                let window = TestWindow(element: nil)!

                layout.updateWithChange(.add(window: window))

                let encodedLayout = try! JSONEncoder().encode(layout)
                let decodedLayout = try! JSONDecoder().decode(BinarySpacePartitioningLayout<TestWindow>.self, from: encodedLayout)

                expect(decodedLayout).to(equal(layout))
            }

            it("encodes and decodes a tree without windows") {
                let layout = BinarySpacePartitioningLayout<TestWindow>()

                let encodedLayout = try! JSONEncoder().encode(layout)

                expect { try JSONDecoder().decode(BinarySpacePartitioningLayout<TestWindow>.self, from: encodedLayout) }.toNot(throwError())
                let decodedLayout = try? JSONDecoder().decode(BinarySpacePartitioningLayout<TestWindow>.self, from: encodedLayout)
                expect(decodedLayout).to(equal(layout))
            }

            it("still rejects an empty node inside a tree") {
                let root = TreeNode<TestWindow>()
                let leaf = TreeNode<TestWindow>()
                leaf.windowID = TestWindow(element: nil)!.id()
                root.left = TreeNode<TestWindow>()
                root.right = leaf

                let encodedTree = try! JSONEncoder().encode(root)

                expect { try JSONDecoder().decode(TreeNode<TestWindow>.self, from: encodedTree) }.to(throwError())
            }

            it("maintains the tree") {
                let layout = BinarySpacePartitioningLayout<TestWindow>()
                let windows = [TestWindow(element: nil)!, TestWindow(element: nil)!, TestWindow(element: nil)!]

                layout.updateWithChange(.add(window: windows[0]))
                layout.updateWithChange(.add(window: windows[1]))
                layout.updateWithChange(.focusChanged(window: windows[0]))
                layout.updateWithChange(.add(window: windows[2]))

                let encodedLayout = try! JSONEncoder().encode(layout)
                let decodedLayout = try! JSONDecoder().decode(BinarySpacePartitioningLayout<TestWindow>.self, from: encodedLayout)

                expect(decodedLayout).to(equal(layout))

                let screen = TestScreen(frame: CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
                TestScreen.availableScreens = [screen]

                let layoutWindows = windows.map {
                    LayoutWindow<TestWindow>(id: $0.id(), frame: $0.frame(), isFocused: false)
                }
                let windowSet = WindowSet<TestWindow>(
                    windows: layoutWindows,
                    isWindowWithIDActive: { _ in return true },
                    isWindowWithIDFloating: { _ in return false },
                    windowForID: { id in return windows.first { $0.id() == id } }
                )

                let assignments = decodedLayout
                    .frameAssignments(windowSet, on: screen)!
                    .map { $0.frameAssignment }
                    .map { [$0.window.id: $0.frame] }
                let expectedAssignments = layout
                    .frameAssignments(windowSet, on: screen)!
                    .map { $0.frameAssignment }
                    .map { [$0.window.id: $0.frame] }
                expect(assignments).to(equal(expectedAssignments))
            }
        }
    }
}

extension TreeNode {
    fileprivate func treeIsValid() -> Bool {
        var valid = self.valid
        if let left = left, let right = right {
            valid = valid && left.parent == self && right.parent == self
            valid = valid && left.treeIsValid() && right.treeIsValid()
        }
        return valid
    }
}
