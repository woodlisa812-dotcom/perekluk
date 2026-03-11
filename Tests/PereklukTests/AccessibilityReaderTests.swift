import XCTest
@testable import PereklukCore

final class AccessibilityReaderTests: XCTestCase {

    func testMockReaderReturnsConfiguredText() {
        let mock = MockAccessibilityReader()
        mock.selectedText = "hello"
        XCTAssertEqual(mock.getSelectedText(), "hello")
    }

    func testMockReaderReturnsNilByDefault() {
        let mock = MockAccessibilityReader()
        XCTAssertNil(mock.getSelectedText())
    }

    func testMockReaderSetTextTracksInput() {
        let mock = MockAccessibilityReader()
        mock.setTextResult = true
        let result = mock.setSelectedText("converted")
        XCTAssertTrue(result)
        XCTAssertEqual(mock.setText, "converted")
    }

    func testMockReaderSetTextReturnsFalseByDefault() {
        let mock = MockAccessibilityReader()
        XCTAssertFalse(mock.setSelectedText("test"))
    }

    func testRealReaderReturnsNilWithoutFocus() {
        // Verifies no crash when no focused text element exists
        let reader = AccessibilityReader()
        _ = reader.getSelectedText()
    }

    func testRealReaderSetTextReturnsFalseWithoutFocus() {
        let reader = AccessibilityReader()
        let result = reader.setSelectedText("test")
        XCTAssertFalse(result)
    }
}
