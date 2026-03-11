import XCTest
import CoreGraphics
@testable import PereklukCore

final class KeyboardMonitorTests: XCTestCase {
    private var monitor: KeyboardMonitor!

    override func setUp() {
        super.setUp()
        monitor = KeyboardMonitor()
    }

    // MARK: - Buffer: basic keystroke accumulation

    func testBufferAccumulatesKeystrokes() {
        typeKeys([VKey.h, .e, .l, .l, .o])
        XCTAssertEqual(monitor.buffer.count, 5)
        XCTAssertEqual(monitor.buffer.map(\.keyCode), [VKey.h, .e, .l, .l, .o].map(\.rawValue))
    }

    func testBufferCapturesShiftState() {
        monitor.handleKeyDown(VKey.a.rawValue, flags: .maskShift)
        XCTAssertTrue(monitor.buffer[0].shift)
        XCTAssertFalse(monitor.buffer[0].capsLock)
    }

    func testBufferCapturesCapsLockState() {
        monitor.handleKeyDown(VKey.a.rawValue, flags: .maskAlphaShift)
        XCTAssertFalse(monitor.buffer[0].shift)
        XCTAssertTrue(monitor.buffer[0].capsLock)
    }

    // MARK: - Buffer: clear on word boundaries

    func testReturnClearsBuffer() {
        typeKeys([VKey.a, .b, .c])
        monitor.handleKeyDown(VKey.return.rawValue, flags: [])
        XCTAssertTrue(monitor.buffer.isEmpty)
    }

    func testTabClearsBuffer() {
        typeKeys([VKey.a, .b])
        monitor.handleKeyDown(VKey.tab.rawValue, flags: [])
        XCTAssertTrue(monitor.buffer.isEmpty)
    }

    func testEscapeClearsBuffer() {
        typeKeys([VKey.a])
        monitor.handleKeyDown(VKey.escape.rawValue, flags: [])
        XCTAssertTrue(monitor.buffer.isEmpty)
    }

    func testEnterNumpadClearsBuffer() {
        typeKeys([VKey.a])
        monitor.handleKeyDown(VKey.enterNumpad.rawValue, flags: [])
        XCTAssertTrue(monitor.buffer.isEmpty)
    }

    // MARK: - Buffer: space does NOT clear, adds to buffer

    func testSpaceAddsToBuffer() {
        typeKeys([VKey.a, .b, .c])
        monitor.handleKeyDown(VKey.space.rawValue, flags: [])
        XCTAssertEqual(monitor.buffer.count, 4)
        XCTAssertEqual(monitor.buffer.last?.keyCode, VKey.space.rawValue)
    }

    // MARK: - Buffer: command/control clear

    func testCommandKeyClearsBuffer() {
        typeKeys([VKey.a, .b])
        monitor.handleKeyDown(VKey.c.rawValue, flags: .maskCommand)
        XCTAssertTrue(monitor.buffer.isEmpty)
    }

    func testControlKeyClearsBuffer() {
        typeKeys([VKey.a, .b])
        monitor.handleKeyDown(VKey.c.rawValue, flags: .maskControl)
        XCTAssertTrue(monitor.buffer.isEmpty)
    }

    // MARK: - Buffer: backspace

    func testBackspaceRemovesLastKeystroke() {
        typeKeys([VKey.a, .b, .c])
        monitor.handleKeyDown(VKey.delete.rawValue, flags: [])
        XCTAssertEqual(monitor.buffer.count, 2)
        XCTAssertEqual(monitor.buffer.map(\.keyCode), [VKey.a, .b].map(\.rawValue))
    }

    func testBackspaceOnEmptyBufferDoesNotCrash() {
        monitor.handleKeyDown(VKey.delete.rawValue, flags: [])
        XCTAssertTrue(monitor.buffer.isEmpty)
    }

    // MARK: - Buffer: mouse click clears

    func testMouseDownClearsBuffer() {
        typeKeys([VKey.a, .b, .c])
        monitor.handleMouseDown()
        XCTAssertTrue(monitor.buffer.isEmpty)
    }

    // MARK: - Buffer: high keycodes clear buffer

    func testHighKeyCodeClearsBuffer() {
        typeKeys([VKey.a, .b])
        monitor.handleKeyDown(55, flags: [])
        XCTAssertTrue(monitor.buffer.isEmpty)
    }

    // MARK: - Buffer: overflow protection

    func testBufferOverflowTrimsOldEntries() {
        for i: UInt16 in 0..<70 {
            monitor.handleKeyDown(i % VKey.maxPrintableRawValue, flags: [])
        }
        XCTAssertLessThanOrEqual(monitor.buffer.count, 64)
    }

    // MARK: - Buffer: Option key suppresses buffering

    func testKeysWhileOptionDownAreNotBuffered() {
        monitor.optionDown = true
        monitor.handleKeyDown(VKey.a.rawValue, flags: [])
        XCTAssertTrue(monitor.buffer.isEmpty)
    }

    func testOptionDownSetsAloneToFalseOnKey() {
        monitor.optionDown = true
        monitor.optionAlone = true
        monitor.handleKeyDown(VKey.a.rawValue, flags: [])
        XCTAssertFalse(monitor.optionAlone)
    }

    // MARK: - extractLastWord via handleFlagsChanged

    func testOptionTriggersCallbackWithWord() {
        var receivedWord: [KeyStroke] = []
        var receivedSpaces = -1
        monitor.onSwitchTriggered = { word, spaces in
            receivedWord = word
            receivedSpaces = spaces
        }

        typeKeys([VKey.h, .e, .l, .l, .o])
        simulateOptionPress()

        XCTAssertEqual(receivedWord.count, 5)
        XCTAssertEqual(receivedSpaces, 0)
    }

    func testWordPlusSpaceThenOption() {
        var receivedWord: [KeyStroke] = []
        var receivedSpaces = -1
        monitor.onSwitchTriggered = { word, spaces in
            receivedWord = word
            receivedSpaces = spaces
        }

        typeKeys([VKey.h, .e, .l, .l, .o, .space])
        simulateOptionPress()

        XCTAssertEqual(receivedWord.count, 5)
        XCTAssertEqual(receivedWord.map(\.keyCode), [VKey.h, .e, .l, .l, .o].map(\.rawValue))
        XCTAssertEqual(receivedSpaces, 1)
    }

    func testTwoWordsThenOption() {
        var receivedWord: [KeyStroke] = []
        var receivedSpaces = -1
        monitor.onSwitchTriggered = { word, spaces in
            receivedWord = word
            receivedSpaces = spaces
        }

        typeKeys([VKey.h, .i, .space, .b, .y, .e])
        simulateOptionPress()

        XCTAssertEqual(receivedWord.count, 3)
        XCTAssertEqual(receivedWord.map(\.keyCode), [VKey.b, .y, .e].map(\.rawValue))
        XCTAssertEqual(receivedSpaces, 0)
    }

    func testTwoWordsPlusSpaceThenOption() {
        var receivedWord: [KeyStroke] = []
        var receivedSpaces = -1
        monitor.onSwitchTriggered = { word, spaces in
            receivedWord = word
            receivedSpaces = spaces
        }

        typeKeys([VKey.h, .i, .space, .b, .y, .e, .space])
        simulateOptionPress()

        XCTAssertEqual(receivedWord.count, 3)
        XCTAssertEqual(receivedWord.map(\.keyCode), [VKey.b, .y, .e].map(\.rawValue))
        XCTAssertEqual(receivedSpaces, 1)
    }

    func testMultipleTrailingSpaces() {
        var receivedWord: [KeyStroke] = []
        var receivedSpaces = -1
        monitor.onSwitchTriggered = { word, spaces in
            receivedWord = word
            receivedSpaces = spaces
        }

        typeKeys([VKey.a, .b, .space, .space, .space])
        simulateOptionPress()

        XCTAssertEqual(receivedWord.count, 2)
        XCTAssertEqual(receivedSpaces, 3)
    }

    func testOnlySpacesThenOption() {
        var receivedWord: [KeyStroke] = []
        var receivedSpaces = -1
        monitor.onSwitchTriggered = { word, spaces in
            receivedWord = word
            receivedSpaces = spaces
        }

        typeKeys([VKey.space, .space])
        simulateOptionPress()

        XCTAssertTrue(receivedWord.isEmpty)
        XCTAssertEqual(receivedSpaces, 2)
    }

    func testEmptyBufferThenOption() {
        var receivedWord: [KeyStroke] = []
        var receivedSpaces = -1
        monitor.onSwitchTriggered = { word, spaces in
            receivedWord = word
            receivedSpaces = spaces
        }

        simulateOptionPress()

        XCTAssertTrue(receivedWord.isEmpty)
        XCTAssertEqual(receivedSpaces, 0)
    }

    // MARK: - Option key alone detection

    func testOptionPlusKeyDoesNotTrigger() {
        var triggered = false
        monitor.onSwitchTriggered = { _, _ in triggered = true }

        monitor.handleFlagsChanged(flags: .maskAlternate)
        monitor.handleKeyDown(VKey.a.rawValue, flags: .maskAlternate)
        monitor.handleFlagsChanged(flags: [])

        XCTAssertFalse(triggered)
    }

    func testOptionAloneTriggers() {
        var triggered = false
        monitor.onSwitchTriggered = { _, _ in triggered = true }

        monitor.handleFlagsChanged(flags: .maskAlternate)
        monitor.handleFlagsChanged(flags: [])

        XCTAssertTrue(triggered)
    }

    func testDoubleOptionPressDoesNotDoubleBuffer() {
        var triggerCount = 0
        monitor.onSwitchTriggered = { _, _ in triggerCount += 1 }

        typeKeys([VKey.a, .b, .c])
        simulateOptionPress()
        simulateOptionPress()

        XCTAssertEqual(triggerCount, 2)
    }

    // MARK: - Helpers

    private func typeKeys(_ keys: [VKey]) {
        for key in keys {
            monitor.handleKeyDown(key.rawValue, flags: [])
        }
    }

    private func simulateOptionPress() {
        monitor.handleFlagsChanged(flags: .maskAlternate)
        monitor.handleFlagsChanged(flags: [])
    }
}
