import AppKit
import Carbon

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    let keyboardMonitor = KeyboardMonitor()
    var inputSourceManager: InputSourceManaging = InputSourceManager()
    var textReplacer: TextReplacing = TextReplacer()
    var pasteboard: PasteboardProviding = NSPasteboard.general
    var accessibilityReader: AccessibilityReading = AccessibilityReader()

    private var appStarted = false

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        observeInputSourceChanges()
        observeAppActivation()
        updateStatusItemTitle()
        startUninstallWatcher()

        if AXIsProcessTrusted() {
            setupKeyboardMonitor()
        } else {
            requestAccessibilityAndWait()
        }
    }

    // MARK: - Accessibility

    private func requestAccessibilityAndWait() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        Timer.scheduledTimer(withTimeInterval: Timing.accessibilityCheckInterval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.setupKeyboardMonitor()
            }
        }
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Perekluk", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func observeAppActivation() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppDidChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func activeAppDidChange(_ notification: Notification) {
        keyboardMonitor.clearBuffer()
    }

    private func observeInputSourceChanges() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceDidChange),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    @objc private func inputSourceDidChange(_ notification: Notification) {
        updateStatusItemTitle()
    }

    private func updateStatusItemTitle() {
        guard let sourceId = inputSourceManager.currentSourceId() else { return }

        let label: String
        if sourceId.localizedCaseInsensitiveContains("russian") {
            label = "Ру"
        } else if sourceId.localizedCaseInsensitiveContains("english") || sourceId.localizedCaseInsensitiveContains("us") {
            label = "En"
        } else {
            label = String(sourceId.split(separator: ".").last?.prefix(2) ?? "??")
        }

        statusItem.button?.title = label
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Uninstall Watcher

    private func startUninstallWatcher() {
        let path = Bundle.main.bundlePath
        Timer.scheduledTimer(withTimeInterval: Timing.uninstallCheckInterval, repeats: true) { timer in
            if !FileManager.default.fileExists(atPath: path) {
                timer.invalidate()
                NSApp.terminate(nil)
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        guard !FileManager.default.fileExists(atPath: Bundle.main.bundlePath) else { return }
        let bundleId = Bundle.main.bundleIdentifier ?? "com.perekluk.app"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleId]
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Keyboard Monitor

    private func setupKeyboardMonitor() {
        keyboardMonitor.onSwitchTriggered = { [weak self] word, trailingSpaces in
            self?.handleSwitch(word, trailingSpaces: trailingSpaces)
        }
        if !keyboardMonitor.start() {
            statusItem.button?.title = "⚠️"
        }
    }

    func handleSwitch(_ word: [KeyStroke], trailingSpaces: Int) {
        if word.isEmpty {
            handleSelectionSwitch()
        } else {
            handleBufferSwitch(word, trailingSpaces: trailingSpaces)
        }
    }

    // MARK: - Clipboard Helpers

    private func savePasteboard() -> [[(NSPasteboard.PasteboardType, Data)]] {
        return (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            }
        }
    }

    private var lastConvertedCharCount = 0

    private func scheduleRestore(_ saved: [[(NSPasteboard.PasteboardType, Data)]]) {
        let restoreChangeCount = pasteboard.changeCount
        let delay = Timing.clipboardRestoreDelay(charCount: lastConvertedCharCount)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            guard pasteboard.changeCount == restoreChangeCount else { return }
            guard !saved.isEmpty else { return }
            pasteboard.clearContents()
            let items = saved.map { itemData -> NSPasteboardItem in
                let item = NSPasteboardItem()
                for (type, data) in itemData { item.setData(data, forType: type) }
                return item
            }
            pasteboard.writeObjects(items)
        }
    }

    // MARK: - Buffer Switch

    private func handleBufferSwitch(_ buffer: [KeyStroke], trailingSpaces: Int) {
        guard let currentId = inputSourceManager.currentSourceId(),
              let otherId = inputSourceManager.otherSourceId(excluding: currentId) else { return }

        guard var newText = inputSourceManager.convertKeyStrokes(
            buffer, fromSourceId: currentId, toSourceId: otherId
        ), !newText.isEmpty else { return }

        if trailingSpaces > 0 {
            newText += String(repeating: " ", count: trailingSpaces)
        }

        let deleteCount = buffer.count + trailingSpaces
        let saved = savePasteboard()
        lastConvertedCharCount = deleteCount
        let deleteDelay = Timing.deleteDelay(charCount: deleteCount)

        DispatchQueue.main.asyncAfter(deadline: .now() + deleteDelay) { [self] in
            textReplacer.deleteChars(count: deleteCount)

            DispatchQueue.main.asyncAfter(deadline: .now() + deleteDelay) { [self] in
                pasteboard.clearContents()
                pasteboard.setString(newText, forType: .string)
                textReplacer.sendPaste()
                inputSourceManager.selectSource(otherId)
                scheduleRestore(saved)
            }
        }
    }

    // MARK: - Selection Switch

    private func handleSelectionSwitch() {
        if let axText = accessibilityReader.getSelectedText(), !axText.isEmpty {
            handleSelectionConversion(axText, usedClipboard: false)
        } else {
            let savedChangeCount = pasteboard.changeCount
            let saved = savePasteboard()
            textReplacer.sendCopy()

            pollPasteboard(savedChangeCount: savedChangeCount) { [self] selectedText in
                guard let selectedText, !selectedText.isEmpty else {
                    inputSourceManager.selectNextSource()
                    return
                }
                handleSelectionConversion(selectedText, usedClipboard: true, savedClipboard: saved)
            }
        }
    }

    private func handleSelectionConversion(
        _ selectedText: String,
        usedClipboard: Bool,
        savedClipboard: [[(NSPasteboard.PasteboardType, Data)]] = []
    ) {
        guard let currentId = inputSourceManager.currentSourceId() else {
            inputSourceManager.selectNextSource()
            return
        }

        let allIds = inputSourceManager.enabledSourceIds()
        guard allIds.count >= 2 else {
            inputSourceManager.selectNextSource()
            return
        }

        let fromId: String
        let toId: String

        if let detected = inputSourceManager.detectTextLayout(
            for: selectedText, candidateIds: allIds
        ) {
            fromId = detected.fromId
            toId = (detected.fromId == currentId)
                ? detected.toId
                : currentId
        } else {
            fromId = currentId
            toId = inputSourceManager.otherSourceId(excluding: currentId) ?? allIds.first { $0 != currentId }!
        }

        guard let converted = inputSourceManager.convertText(
            selectedText, fromSourceId: fromId, toSourceId: toId
        ) else {
            inputSourceManager.selectNextSource()
            return
        }

        lastConvertedCharCount = converted.count

        if !usedClipboard && accessibilityReader.setSelectedText(converted) {
            if toId != currentId {
                inputSourceManager.selectSource(toId)
            }
        } else {
            pasteboard.clearContents()
            pasteboard.setString(converted, forType: .string)
            textReplacer.sendPaste()

            if toId != currentId {
                inputSourceManager.selectSource(toId)
            }

            if usedClipboard {
                scheduleRestore(savedClipboard)
            }
        }
    }

    private func pollPasteboard(
        savedChangeCount: Int,
        attempt: Int = 0,
        completion: @escaping (String?) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.pasteboardPollInterval) { [self] in
            if pasteboard.changeCount != savedChangeCount {
                completion(pasteboard.string(forType: .string))
                return
            }
            if attempt + 1 < Timing.pasteboardPollMaxAttempts {
                self.pollPasteboard(
                    savedChangeCount: savedChangeCount,
                    attempt: attempt + 1,
                    completion: completion
                )
            } else {
                completion(nil)
            }
        }
    }
}
