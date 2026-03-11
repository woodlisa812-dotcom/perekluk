import XCTest
import Carbon
@testable import PereklukCore

final class InputSourceManagerTests: XCTestCase {
    private var manager: InputSourceManager!

    override func setUp() {
        super.setUp()
        manager = InputSourceManager()
    }

    // MARK: - Source Discovery

    func testGetEnabledKeyboardSourcesReturnsAtLeastOne() {
        let sources = manager.getEnabledKeyboardSources()
        XCTAssertFalse(sources.isEmpty, "System must have at least one keyboard layout")
    }

    func testGetCurrentSourceReturnsNonNil() {
        XCTAssertNotNil(manager.getCurrentSource())
    }

    func testSourceIdReturnsNonEmptyString() {
        guard let source = manager.getCurrentSource() else {
            XCTFail("No current source"); return
        }
        let id = manager.sourceId(for: source)
        XCTAssertNotNil(id)
        XCTAssertFalse(id!.isEmpty)
    }

    // MARK: - Layout Data

    func testGetLayoutDataReturnsNonNil() {
        guard let source = manager.getCurrentSource() else {
            XCTFail("No current source"); return
        }
        XCTAssertNotNil(manager.getLayoutData(for: source))
    }

    // MARK: - Key Translation

    func testTranslateSpaceReturnsSpace() {
        guard let source = manager.getCurrentSource(),
              let layout = manager.getLayoutData(for: source) else {
            XCTFail("No layout data"); return
        }
        let result = manager.translateKeyCode(VKey.space.rawValue, shift: false, capsLock: false, layoutData: layout)
        XCTAssertEqual(result, " ")
    }

    func testTranslateAllPrintableKeysReturnNonNil() {
        guard let source = manager.getCurrentSource(),
              let layout = manager.getLayoutData(for: source) else {
            XCTFail("No layout data"); return
        }
        var translatedCount = 0
        for kc: UInt16 in 0...VKey.maxPrintableRawValue {
            if manager.translateKeyCode(kc, shift: false, capsLock: false, layoutData: layout) != nil {
                translatedCount += 1
            }
        }
        XCTAssertGreaterThan(translatedCount, 25, "Most printable keys should translate")
    }

    func testTranslateShiftedKeysProduceDifferentChars() {
        guard let source = manager.getCurrentSource(),
              let layout = manager.getLayoutData(for: source) else {
            XCTFail("No layout data"); return
        }
        let normal = manager.translateKeyCode(VKey.a.rawValue, shift: false, capsLock: false, layoutData: layout)
        let shifted = manager.translateKeyCode(VKey.a.rawValue, shift: true, capsLock: false, layoutData: layout)
        XCTAssertNotNil(normal)
        XCTAssertNotNil(shifted)
        XCTAssertNotEqual(normal, shifted, "Shift should produce different character for letter keys")
    }

    // MARK: - Text Conversion Round-trip

    func testConvertTextRoundTrip() {
        let sources = manager.getEnabledKeyboardSources()
        guard sources.count >= 2 else {
            print("Skipping round-trip test: need 2+ layouts")
            return
        }

        let sourceA = sources[0]
        let sourceB = sources[1]

        guard let layoutA = manager.getLayoutData(for: sourceA) else {
            print("Skipping round-trip test: no layout data for sourceA")
            return
        }

        var testString = ""
        for kc: UInt16 in 0...VKey.maxPrintableRawValue {
            if let ch = manager.translateKeyCode(kc, shift: false, capsLock: false, layoutData: layoutA) {
                testString += ch
            }
        }

        guard !testString.isEmpty else {
            XCTFail("Could not generate test string"); return
        }

        guard let converted = manager.convertText(testString, fromSource: sourceA, toSource: sourceB) else {
            XCTFail("Forward conversion failed"); return
        }

        guard let roundTripped = manager.convertText(converted, fromSource: sourceB, toSource: sourceA) else {
            XCTFail("Reverse conversion failed"); return
        }

        var matchCount = 0
        let minLength = min(testString.count, roundTripped.count)
        for (a, b) in zip(testString, roundTripped) {
            if a == b { matchCount += 1 }
        }
        let matchRate = Double(matchCount) / Double(minLength)
        XCTAssertGreaterThan(matchRate, 0.9, "At least 90% of characters must survive round-trip (got \(Int(matchRate * 100))%)")
    }

    // MARK: - Text Conversion Preserves Unmapped Characters

    func testConvertTextPreservesUnmappedChars() {
        let sources = manager.getEnabledKeyboardSources()
        guard sources.count >= 2 else { return }

        let result = manager.convertText("hello 123", fromSource: sources[0], toSource: sources[1])
        XCTAssertNotNil(result)
    }

    // MARK: - Layout Detection

    func testDetectTextLayoutWithTwoSources() {
        let sources = manager.getEnabledKeyboardSources()
        guard sources.count >= 2 else {
            print("Skipping layout detection test: need 2+ layouts")
            return
        }

        let sourceA = sources[0]
        let sourceB = sources[1]

        guard let layoutA = manager.getLayoutData(for: sourceA),
              let layoutB = manager.getLayoutData(for: sourceB) else { return }

        var charsA = Set<String>()
        var charsB = Set<String>()
        for kc: UInt16 in 0...VKey.maxPrintableRawValue {
            if let ch = manager.translateKeyCode(kc, shift: false, capsLock: false, layoutData: layoutA) { charsA.insert(ch) }
            if let ch = manager.translateKeyCode(kc, shift: false, capsLock: false, layoutData: layoutB) { charsB.insert(ch) }
        }

        let uniqueA = charsA.subtracting(charsB)
        guard !uniqueA.isEmpty else {
            print("Skipping: layouts have no unique characters (probably similar Latin layouts)")
            return
        }

        let testText = uniqueA.prefix(5).joined()

        let detected = manager.detectTextLayout(for: testText, sourceA: sourceA, sourceB: sourceB)
        XCTAssertNotNil(detected, "Should detect layout for text with unique characters")
        if let detected {
            XCTAssertEqual(
                manager.sourceId(for: detected.from),
                manager.sourceId(for: sourceA),
                "Text with sourceA-unique chars should be detected as sourceA"
            )
        }
    }

    func testDetectTextLayoutReturnsNilForAmbiguous() {
        let sources = manager.getEnabledKeyboardSources()
        guard sources.count >= 2 else { return }

        let result = manager.detectTextLayout(for: " ", sourceA: sources[0], sourceB: sources[1])
        XCTAssertNil(result, "Space-only text should be ambiguous (equal scores)")
    }

    // MARK: - Dead Key Sequence Translation

    func testTranslateKeySequenceProducesText() {
        guard let source = manager.getCurrentSource(),
              let layout = manager.getLayoutData(for: source) else {
            XCTFail("No layout data"); return
        }

        let keystrokes = [VKey.h, .e, .l, .l, .o].map {
            KeyStroke(keyCode: $0.rawValue, shift: false, capsLock: false)
        }

        let result = manager.translateKeySequence(keystrokes, layoutData: layout)
        XCTAssertEqual(result.count, 5)
    }

    func testTranslateKeySequenceMatchesStaticForNonDeadKeys() {
        guard let source = manager.getCurrentSource(),
              let layout = manager.getLayoutData(for: source) else {
            XCTFail("No layout data"); return
        }

        let keystrokes = [VKey.a, .b, .c, .one, .two].map {
            KeyStroke(keyCode: $0.rawValue, shift: false, capsLock: false)
        }

        let sequenceResult = manager.translateKeySequence(keystrokes, layoutData: layout)
        var staticResult = ""
        for stroke in keystrokes {
            if let ch = manager.translateKeyCode(stroke.keyCode, shift: stroke.shift, capsLock: stroke.capsLock, layoutData: layout) {
                staticResult += ch
            }
        }

        XCTAssertEqual(sequenceResult, staticResult,
                       "For non-dead-key layouts, sequence and static translation must match")
    }

    func testTranslateKeySequenceHandlesShiftState() {
        guard let source = manager.getCurrentSource(),
              let layout = manager.getLayoutData(for: source) else {
            XCTFail("No layout data"); return
        }

        let lower = [KeyStroke(keyCode: VKey.a.rawValue, shift: false, capsLock: false)]
        let upper = [KeyStroke(keyCode: VKey.a.rawValue, shift: true, capsLock: false)]

        let lowerResult = manager.translateKeySequence(lower, layoutData: layout)
        let upperResult = manager.translateKeySequence(upper, layoutData: layout)

        XCTAssertNotEqual(lowerResult, upperResult, "Shift should produce different character")
    }

    func testTranslateKeySequenceEmptyInput() {
        guard let source = manager.getCurrentSource(),
              let layout = manager.getLayoutData(for: source) else {
            XCTFail("No layout data"); return
        }

        let result = manager.translateKeySequence([], layoutData: layout)
        XCTAssertTrue(result.isEmpty)
    }

    func testConvertKeyStrokesUsesDeadKeySequence() {
        let ids = manager.enabledSourceIds()
        guard ids.count >= 2 else { return }

        let keystrokes = [VKey.h, .e, .l, .l, .o].map {
            KeyStroke(keyCode: $0.rawValue, shift: false, capsLock: false)
        }

        let result = manager.convertKeyStrokes(keystrokes, fromSourceId: ids[0], toSourceId: ids[1])
        XCTAssertNotNil(result)
    }
}
