import AppKit
import InputMethodKit
import ShunTypeCore

@objc(ShunTypeInputController)
final class ShunTypeInputController: IMKInputController {
    private var composition = Composition()
    private weak var currentClient: IMKTextInput?
    private var candidateWindow: NSPanel?

    override func recognizedEvents(_ sender: Any!) -> Int { Int(NSEvent.EventTypeMask.keyDown.rawValue) }

    override func activateServer(_ sender: Any!) {
        currentClient = sender as? IMKTextInput
        composition.reset()
        currentClient?.overrideKeyboard(withKeyboardNamed: "com.apple.keylayout.ABC")
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let input = sender as? IMKTextInput, event.type == .keyDown else { return false }
        currentClient = input
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control), flags.intersection([.command, .option, .shift]).isEmpty, event.keyCode == 42 {
            finish(input)
            let modes = InputMode.allCases
            let index = modes.firstIndex(of: composition.mode) ?? 0
            composition.mode = modes[(index + 1) % modes.count]
            showCandidates(input, message: composition.mode.title)
            return true
        }
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            finish(input); return false
        }
        let key: InputKey
        switch event.keyCode {
        case 36, 76: key = .enter
        case 53: key = .escape
        case 51: key = .backspace
        case 49: key = .space
        case 48, 125: key = flags.contains(.shift) ? .previousCandidate : .nextCandidate
        case 126: key = .previousCandidate
        case 123, 124, 115, 119, 116, 121, 117: key = .boundary
        default: key = .text(PhysicalKeyboard.text(keyCode: event.keyCode, fallback: event.characters ?? "", shift: flags.contains(.shift), capsLock: flags.contains(.capsLock)))
        }
        let hadComposition = !composition.raw.isEmpty
        let update = composition.process(key)
        apply(update, input, hadComposition: hadComposition)
        if key == .nextCandidate || key == .previousCandidate {
            if update.consumed { showCandidates(input) }
        } else { candidateWindow?.orderOut(nil) }
        return update.consumed
    }

    private func apply(_ update: CompositionUpdate, _ client: IMKTextInput, hadComposition: Bool = true) {
        let replacement = NSRange(location: NSNotFound, length: 0)
        if let committed = update.committed { client.insertText(committed, replacementRange: replacement) }
        if !update.marked.isEmpty {
            let marked = NSAttributedString(string: update.marked, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
            client.setMarkedText(marked, selectionRange: NSRange(location: marked.length, length: 0), replacementRange: replacement)
        } else if update.committed == nil && hadComposition {
            client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: replacement)
        }
    }

    private func finish(_ input: IMKTextInput) {
        guard !composition.raw.isEmpty else { candidateWindow?.orderOut(nil); return }
        apply(composition.process(.boundary), input)
        candidateWindow?.orderOut(nil)
    }
    override func commitComposition(_ sender: Any!) { if let input = (sender as? IMKTextInput) ?? currentClient { finish(input) } }
    override func deactivateServer(_ sender: Any!) {
        if let input = (sender as? IMKTextInput) ?? currentClient { finish(input) }
        currentClient = nil; candidateWindow?.orderOut(nil)
    }
    override func composedString(_ sender: Any!) -> Any! { composition.rendered }
    override func originalString(_ sender: Any!) -> NSAttributedString! { NSAttributedString(string: composition.raw) }
    override func candidates(_ sender: Any!) -> [Any]! { composition.analysis.candidates.map(\.text) }
    override func hidePalettes() { candidateWindow?.orderOut(nil); super.hidePalettes() }

    private func showCandidates(_ input: IMKTextInput, message: String? = nil) {
        let a = composition.analysis
        let strings = a.candidates.prefix(5).enumerated().map { index, item in
            "\(index == composition.selectedIndex ? "●" : "○") \(item.text)"
        }
        let text = message ?? strings.joined(separator: "   ")
        guard !text.isEmpty else { return }
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 16); label.textColor = .labelColor
        let size = label.fittingSize
        let panel = candidateWindow ?? NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu; panel.hasShadow = true; panel.hidesOnDeactivate = false
        panel.backgroundColor = .windowBackgroundColor; panel.isOpaque = false
        let view = NSView(frame: NSRect(x: 0, y: 0, width: min(size.width + 30, 800), height: 48))
        label.frame = NSRect(x: 15, y: 13, width: min(size.width, 770), height: 24)
        view.addSubview(label); panel.contentView = view
        var caret = NSRect.zero
        let selection = input.selectedRange()
        _ = input.attributes(forCharacterIndex: selection.location == NSNotFound ? 0 : selection.location, lineHeightRectangle: &caret)
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(caret) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let origin = caret == .zero ? NSPoint(x: visible.midX - view.frame.width / 2, y: visible.midY) : NSPoint(x: caret.minX, y: caret.minY - 52)
        panel.setFrame(NSRect(x: max(visible.minX, min(origin.x, visible.maxX - view.frame.width)), y: max(visible.minY, min(origin.y, visible.maxY - 48)), width: view.frame.width, height: 48), display: true)
        panel.orderFrontRegardless(); candidateWindow = panel
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        for mode in InputMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = mode.rawValue
            item.state = composition.mode == mode ? .on : .off
            menu.addItem(item)
        }
        return menu
    }
    @objc private func selectMode(_ sender: NSMenuItem) {
        if let input = currentClient { finish(input) }
        if let raw = sender.representedObject as? String, let mode = InputMode(rawValue: raw) { composition.mode = mode }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let bundle = Bundle.main
let server = IMKServer(name: bundle.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String ?? "ShunType_Connection", bundleIdentifier: bundle.bundleIdentifier ?? "org.shuntype.inputmethod")
_ = Decoder.shared
app.run()
withExtendedLifetime(server) {}
