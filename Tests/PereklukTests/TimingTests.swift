import XCTest
@testable import PereklukCore

final class TimingTests: XCTestCase {

    func testDeleteDelayIsMonotonicallyIncreasing() {
        var prev = Timing.deleteDelay(charCount: 1)
        for count in 2...50 {
            let current = Timing.deleteDelay(charCount: count)
            XCTAssertGreaterThanOrEqual(current, prev,
                "deleteDelay must increase with char count (count=\(count))")
            prev = current
        }
    }

    func testClipboardRestoreDelayIsMonotonicallyIncreasing() {
        var prev = Timing.clipboardRestoreDelay(charCount: 1)
        for count in 2...50 {
            let current = Timing.clipboardRestoreDelay(charCount: count)
            XCTAssertGreaterThanOrEqual(current, prev,
                "clipboardRestoreDelay must increase with char count (count=\(count))")
            prev = current
        }
    }

    func testDeleteDelayBaseIsReasonable() {
        let base = Timing.deleteDelay(charCount: 1)
        XCTAssertGreaterThan(base, 0.01, "Base delay should be at least 10ms")
        XCTAssertLessThan(base, 0.2, "Base delay should be under 200ms")
    }

    func testDeleteDelayForLargeCountIsReasonable() {
        let delay = Timing.deleteDelay(charCount: 64)
        XCTAssertLessThan(delay, 1.0, "64-char delete delay should be under 1 second")
    }

    func testClipboardRestoreBaseIsReasonable() {
        let base = Timing.clipboardRestoreDelay(charCount: 1)
        XCTAssertGreaterThan(base, 0.05, "Restore base should be at least 50ms")
        XCTAssertLessThan(base, 0.5, "Restore base should be under 500ms")
    }

    func testClipboardRestoreForLargeCountIsReasonable() {
        let delay = Timing.clipboardRestoreDelay(charCount: 64)
        XCTAssertLessThan(delay, 2.0, "64-char restore delay should be under 2 seconds")
    }

    func testDeleteDelayZeroCharCountDoesNotCrash() {
        let delay = Timing.deleteDelay(charCount: 0)
        XCTAssertGreaterThanOrEqual(delay, 0)
    }

    func testClipboardRestoreDelayNegativeCharCountDoesNotCrash() {
        let delay = Timing.clipboardRestoreDelay(charCount: -1)
        XCTAssertGreaterThanOrEqual(delay, 0)
    }
}
