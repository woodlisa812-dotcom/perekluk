import CoreGraphics
import Carbon

public struct KeyStroke {
    public let keyCode: UInt16
    public let shift: Bool
    public let capsLock: Bool

    public init(keyCode: UInt16, shift: Bool, capsLock: Bool) {
        self.keyCode = keyCode
        self.shift = shift
        self.capsLock = capsLock
    }
}

public final class KeyboardMonitor {
    public var onSwitchTriggered: ((_ word: [KeyStroke], _ trailingSpaces: Int) -> Void)?

    public private(set) var buffer: [KeyStroke] = []
    public var eventTap: CFMachPort?

    public var optionDown = false
    public var optionAlone = false

    private let maxBufferSize = 64

    public init() {}

    @discardableResult
    public func start() -> Bool {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            return false
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    public func clearBuffer() {
        buffer.removeAll(keepingCapacity: true)
    }

    public func handleKeyDown(_ keyCode: UInt16, flags: CGEventFlags) {
        if optionDown {
            optionAlone = false
            return
        }

        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            clearBuffer()
            return
        }

        if Self.wordBoundaryKeys.contains(keyCode) {
            clearBuffer()
            return
        }

        if keyCode == VKey.delete.rawValue {
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            return
        }

        guard keyCode <= VKey.maxPrintableRawValue else {
            clearBuffer()
            return
        }

        let shift = flags.contains(.maskShift)
        let capsLock = flags.contains(.maskAlphaShift)
        buffer.append(KeyStroke(keyCode: keyCode, shift: shift, capsLock: capsLock))

        if buffer.count > maxBufferSize {
            buffer.removeFirst(buffer.count - maxBufferSize)
        }
    }

    public func handleFlagsChanged(flags: CGEventFlags) {
        let optionPressed = flags.contains(.maskAlternate)

        if optionPressed && !optionDown {
            optionDown = true
            optionAlone = true
        } else if !optionPressed && optionDown {
            if optionAlone {
                let (word, trailing) = extractLastWord()
                onSwitchTriggered?(word, trailing)
            }
            optionDown = false
            optionAlone = false
        }
    }

    // MARK: - Last Word Extraction (xneur "trailing delimiter skip" algorithm)

    private func extractLastWord() -> (word: [KeyStroke], trailingSpaces: Int) {
        guard !buffer.isEmpty else { return ([], 0) }

        var end = buffer.count

        while end > 0 && buffer[end - 1].keyCode == VKey.space.rawValue {
            end -= 1
        }

        let trailingSpaces = buffer.count - end

        guard end > 0 else { return ([], trailingSpaces) }

        var start = end
        while start > 0 && buffer[start - 1].keyCode != VKey.space.rawValue {
            start -= 1
        }

        return (Array(buffer[start..<end]), trailingSpaces)
    }

    public func handleMouseDown() {
        clearBuffer()
    }

    // MARK: - Key Constants

    private static let wordBoundaryKeys: Set<UInt16> = [
        VKey.return.rawValue,
        VKey.enterNumpad.rawValue,
        VKey.tab.rawValue,
        VKey.escape.rawValue,
    ]
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }
    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = monitor.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    if event.getIntegerValueField(.eventSourceUserData) == TextReplacer.markerUserData {
        return Unmanaged.passUnretained(event)
    }

    switch type {
    case .keyDown:
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        monitor.handleKeyDown(keyCode, flags: event.flags)

    case .flagsChanged:
        monitor.handleFlagsChanged(flags: event.flags)

    case .leftMouseDown, .rightMouseDown:
        monitor.handleMouseDown()

    default:
        break
    }

    return Unmanaged.passUnretained(event)
}
