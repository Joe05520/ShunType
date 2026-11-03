import AppKit
import SwiftUI
import ShunTypeCore

struct LiveEditor: NSViewRepresentable {
    @ObservedObject var model: StudioModel
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let text = TypingTextView(frame: .zero)
        text.isRichText = false; text.allowsUndo = true
        text.font = .systemFont(ofSize: 23)
        text.textColor = .labelColor; text.backgroundColor = .clear; text.drawsBackground = false
        text.textContainerInset = NSSize(width: 19, height: 20)
        text.isVerticallyResizable = true; text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        text.isAutomaticSpellingCorrectionEnabled = false
        text.setAccessibilityLabel("順打互動試打區")
        text.setAccessibilityIdentifier("live-editor")
        text.string = model.document
        text.onUpdate = { [weak model] update, document in
            DispatchQueue.main.async { model?.receive(update, document: document) }
        }
        scroll.documentView = text; scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let text = scroll.documentView as? TypingTextView else { return }
        if text.session.mode != model.mode { text.flush(); text.session.mode = model.mode }
        if text.commandID != model.commandID {
            text.commandID = model.commandID
            text.session.reset(); text.unmarkText(); text.string = ""
            for char in model.demo { text.apply(text.session.process(char == " " ? .space : .text(String(char)))) }
            text.publish()
            DispatchQueue.main.async { text.window?.makeFirstResponder(text) }
        }
    }
}

final class TypingTextView: NSTextView {
    var session = Composition()
    var commandID = 0
    var onUpdate: ((CompositionUpdate, String) -> Void)?
    private var applying = false

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
            flush(); super.keyDown(with: event); publish(); return
        }
        let key: InputKey
        switch event.keyCode {
        case 36, 76: key = .enter
        case 53: key = .escape
        case 51: key = .backspace
        case 48, 125: key = flags.contains(.shift) ? .previousCandidate : .nextCandidate
        case 126: key = .previousCandidate
        case 49: key = .space
        case 123, 124, 115, 119, 116, 121, 117: key = .boundary
        default: key = .text(PhysicalKeyboard.text(keyCode: event.keyCode, fallback: event.characters ?? "", shift: flags.contains(.shift), capsLock: flags.contains(.capsLock)))
        }
        let update = session.process(key)
        apply(update)
        if !update.consumed { super.keyDown(with: event) }
        publish()
    }

    func apply(_ update: CompositionUpdate) {
        applying = true
        if let commit = update.committed { super.insertText(commit, replacementRange: NSRange(location: NSNotFound, length: 0)) }
        if !update.marked.isEmpty {
            let marked = NSAttributedString(string: update.marked, attributes: [
                .font: NSFont.systemFont(ofSize: 23), .foregroundColor: NSColor.labelColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: NSColor.systemTeal
            ])
            super.setMarkedText(marked, selectedRange: NSRange(location: marked.length, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        } else {
            if update.committed == nil && hasMarkedText() {
                super.setMarkedText("", selectedRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
            }
            unmarkText()
        }
        applying = false
    }

    func flush() {
        guard !session.raw.isEmpty else { return }
        apply(session.process(.boundary)); publish()
    }
    func publish() {
        let a = session.analysis
        onUpdate?(CompositionUpdate(consumed: true, committed: nil, marked: session.rendered, raw: session.raw, analysis: a, selectedIndex: session.selectedIndex), string)
    }
    override func mouseDown(with event: NSEvent) { flush(); super.mouseDown(with: event) }
    override func resignFirstResponder() -> Bool { flush(); return super.resignFirstResponder() }
    override func paste(_ sender: Any?) { flush(); super.paste(sender); publish() }
    override func cut(_ sender: Any?) { flush(); super.cut(sender); publish() }
    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        if !applying { flush() }
        super.insertText(insertString, replacementRange: replacementRange)
        if !applying { publish() }
    }
}
