import AppKit

public protocol AccessibilityReading {
    func getSelectedText() -> String?
    func setSelectedText(_ text: String) -> Bool
}

public final class AccessibilityReader: AccessibilityReading {

    public init() {}

    public func getSelectedText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRaw
        ) == .success else { return nil }

        let focused = focusedRaw as! AXUIElement
        var textRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &textRaw
        ) == .success else { return nil }

        let text = textRaw as? String
        return (text?.isEmpty == true) ? nil : text
    }

    public func setSelectedText(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRaw
        ) == .success else { return false }

        let focused = focusedRaw as! AXUIElement
        let result = AXUIElementSetAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return result == .success
    }
}
