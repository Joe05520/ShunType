import AppKit
import InputMethodKit
import ShunTypeCore
import os

/// Text delivery is separate from IMK's controller construction, which requires a
/// real OS client proxy. This session can also be exercised with a synthetic client.
final class InputSession: NSObject {
    private var composition = Composition()
    private weak var currentClient: IMKTextInput?
    private var candidateWindow: NSPanel?
    private var reportedClientMismatch = false
    private let diagnostics = Logger(subsystem: "org.shuntype.inputmethod", category: "integration")

    func activate(_ sender: Any!) {
        currentClient = sender as? IMKTextInput
    }

    func processEvent(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown else { return false }
        guard let input = sender as? IMKTextInput else {
            if !reportedClientMismatch { diagnostics.error("Input client does not declare IMKTextInput conformance"); reportedClientMismatch = true }
            return false
        }
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
    func commit(_ sender: Any!) { if let input = (sender as? IMKTextInput) ?? currentClient { finish(input) } }
    func deactivate(_ sender: Any!) {
        if let input = (sender as? IMKTextInput) ?? currentClient { finish(input) }
        currentClient = nil; candidateWindow?.orderOut(nil)
    }
    func composedText(_ sender: Any!) -> Any! { composition.rendered }
    func originalText(_ sender: Any!) -> NSAttributedString! { NSAttributedString(string: composition.raw) }
    func candidateTexts(_ sender: Any!) -> [Any]! { composition.analysis.candidates.map(\.text) }
    func dismissCandidates() { candidateWindow?.orderOut(nil) }

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

    func makeMenu() -> NSMenu! {
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

@objc(ShunTypeInputController)
final class ShunTypeInputController: IMKInputController {
    private let session = InputSession()
    override func recognizedEvents(_ sender: Any!) -> Int { Int(NSEvent.EventTypeMask.keyDown.rawValue) }
    override func activateServer(_ sender: Any!) { session.activate(sender) }
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool { session.processEvent(event, client: sender) }
    override func commitComposition(_ sender: Any!) { session.commit(sender) }
    override func deactivateServer(_ sender: Any!) { session.deactivate(sender) }
    override func composedString(_ sender: Any!) -> Any! { session.composedText(sender) }
    override func originalString(_ sender: Any!) -> NSAttributedString! { session.originalText(sender) }
    override func candidates(_ sender: Any!) -> [Any]! { session.candidateTexts(sender) }
    override func hidePalettes() { session.dismissCandidates(); super.hidePalettes() }
    override func menu() -> NSMenu! { session.makeMenu() }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let bundle = Bundle.main
let checking = CommandLine.arguments.contains("--self-check")
guard let identifier = bundle.bundleIdentifier,
      let connection = bundle.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String,
      let controllerName = bundle.object(forInfoDictionaryKey: "InputMethodServerControllerClass") as? String,
      NSClassFromString(controllerName) == ShunTypeInputController.self else {
    fputs("Invalid input method bundle configuration: id=\(bundle.bundleIdentifier ?? "missing"), connection=\(bundle.object(forInfoDictionaryKey: "InputMethodConnectionName") ?? "missing"), controller=\(bundle.object(forInfoDictionaryKey: "InputMethodServerControllerClass") ?? "missing"), expected=\(NSStringFromClass(ShunTypeInputController.self)).\n", stderr)
    exit(1)
}
// The controllerClass initializer crashes inside _IMKServerLegacy on macOS 27.
// Use the bundle-based initializer so IMK resolves the controller from Info.plist.
// Checks use a separate connection and never register or select an input source.
guard let server = IMKServer(name: checking ? "\(identifier).check.\(UUID().uuidString)_Connection" : connection,
                             bundleIdentifier: identifier) else {
    fputs("Could not create the input method server.\n", stderr)
    exit(1)
}
_ = Decoder.shared
if checking {
    guard checkInputAdapter() else {
        fputs("Synthetic input adapter check failed.\n", stderr)
        exit(1)
    }
    print("IMK server initialized; controller class resolved; dictionary loaded. No input source was registered or selected.")
    exit(0)
}
app.run()
withExtendedLifetime(server) {}
