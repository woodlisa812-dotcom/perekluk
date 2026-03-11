import XCTest
import Carbon
@testable import PereklukCore

final class LayoutSnapshotTests: XCTestCase {
    private var manager: InputSourceManager!

    override func setUp() {
        super.setUp()
        manager = InputSourceManager()
    }

    // MARK: - Full Keymap Snapshot

    func testAllKeycodesMappedForCurrentLayout() {
        guard let source = manager.getCurrentSource(),
              let layout = manager.getLayoutData(for: source),
              let sourceId = manager.sourceId(for: source) else {
            XCTFail("No current layout available"); return
        }

        var mapping: [(keyCode: UInt16, normal: String?, shifted: String?)] = []
        for kc: UInt16 in 0...VKey.maxPrintableRawValue {
            let normal = manager.translateKeyCode(kc, shift: false, capsLock: false, layoutData: layout)
            let shifted = manager.translateKeyCode(kc, shift: true, capsLock: false, layoutData: layout)
            mapping.append((kc, normal, shifted))
        }

        let mapped = mapping.filter { $0.normal != nil }
        XCTAssertGreaterThan(mapped.count, 40, "Layout '\(sourceId)' should map at least 40 of 51 keycodes, got \(mapped.count)")

        let shiftDiffers = mapping.filter { $0.normal != nil && $0.shifted != nil && $0.normal != $0.shifted }
        XCTAssertGreaterThan(shiftDiffers.count, 20, "At least 20 keys should have different shifted output, got \(shiftDiffers.count)")
    }

    func testBothLayoutsMapMostKeycodes() {
        let sources = manager.getEnabledKeyboardSources()
        guard sources.count >= 2,
              let layoutA = manager.getLayoutData(for: sources[0]),
              let layoutB = manager.getLayoutData(for: sources[1]) else {
            print("Skipping: need 2 layouts with data")
            return
        }

        var countA = 0, countB = 0
        for kc: UInt16 in 0...VKey.maxPrintableRawValue {
            if manager.translateKeyCode(kc, shift: false, capsLock: false, layoutData: layoutA) != nil { countA += 1 }
            if manager.translateKeyCode(kc, shift: false, capsLock: false, layoutData: layoutB) != nil { countB += 1 }
        }

        XCTAssertGreaterThan(countA, 40, "Layout A should map at least 40 keycodes, got \(countA)")
        XCTAssertGreaterThan(countB, 40, "Layout B should map at least 40 keycodes, got \(countB)")
    }

    // MARK: - Conversion Consistency

    func testConversionIsConsistentAcrossMultipleCalls() {
        let sources = manager.getEnabledKeyboardSources()
        guard sources.count >= 2 else { return }

        let testText = "hello world"
        let result1 = manager.convertText(testText, fromSource: sources[0], toSource: sources[1])
        let result2 = manager.convertText(testText, fromSource: sources[0], toSource: sources[1])

        XCTAssertEqual(result1, result2, "Same input must produce same output across calls")
    }

    func testConversionPreservesLength() {
        let sources = manager.getEnabledKeyboardSources()
        guard sources.count >= 2 else { return }

        let testText = "abcdefghij"
        guard let converted = manager.convertText(testText, fromSource: sources[0], toSource: sources[1]) else {
            XCTFail("Conversion failed"); return
        }

        XCTAssertEqual(converted.count, testText.count, "Converted text must have same length as input")
    }

    // MARK: - VKey Constants Integrity

    func testVKeySpaceIsCorrect() {
        guard let source = manager.getCurrentSource(),
              let layout = manager.getLayoutData(for: source) else { return }

        let result = manager.translateKeyCode(VKey.space.rawValue, shift: false, capsLock: false, layoutData: layout)
        XCTAssertEqual(result, " ")
    }

    func testVKeyReturnIsCorrect() {
        guard let source = manager.getCurrentSource(),
              let layout = manager.getLayoutData(for: source) else { return }

        let result = manager.translateKeyCode(VKey.return.rawValue, shift: false, capsLock: false, layoutData: layout)
        XCTAssertNotNil(result)
    }

    func testVKeyTabIsCorrect() {
        guard let source = manager.getCurrentSource(),
              let layout = manager.getLayoutData(for: source) else { return }

        let result = manager.translateKeyCode(VKey.tab.rawValue, shift: false, capsLock: false, layoutData: layout)
        XCTAssertNotNil(result)
    }

    func testVKeyDeleteIsNotPrintable() {
        XCTAssertGreaterThan(VKey.delete.rawValue, VKey.maxPrintableRawValue,
                             "Delete keyCode must be above maxPrintableRawValue")
    }

    func testVKeyEscapeIsNotPrintable() {
        XCTAssertGreaterThan(VKey.escape.rawValue, VKey.maxPrintableRawValue,
                             "Escape keyCode must be above maxPrintableRawValue")
    }
}
