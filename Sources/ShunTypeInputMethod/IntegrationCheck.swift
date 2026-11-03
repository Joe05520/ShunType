import AppKit
import Carbon
import InputMethodKit

/// Synthetic client used only by --self-check. It does not read the user's document,
/// register an input source, or send keyboard events to another process.
private final class CheckClient: NSObject, IMKTextInput {
    let text = NSMutableString(string: "prefix ")
    var selection = NSRange(location: 7, length: 0)
    var marking = NSRange(location: NSNotFound, length: 0)

    private func string(_ value: Any?) -> String {
        (value as? NSAttributedString)?.string ?? (value as? String ?? "")
    }
    private func replace(_ value: String, range: NSRange) -> NSRange {
        let target = range.location != NSNotFound ? range : (marking.location != NSNotFound ? marking : selection)
        text.replaceCharacters(in: target, with: value)
        let inserted = NSRange(location: target.location, length: (value as NSString).length)
        selection = NSRange(location: NSMaxRange(inserted), length: 0)
        return inserted
    }
    func insertText(_ string: Any!, replacementRange range: NSRange) {
        _ = replace(self.string(string), range: range)
        marking = NSRange(location: NSNotFound, length: 0)
    }
    func setMarkedText(_ string: Any!, selectionRange: NSRange, replacementRange: NSRange) {
        marking = replace(self.string(string), range: replacementRange)
        selection = NSRange(location: marking.location + selectionRange.location, length: selectionRange.length)
        if marking.length == 0 { marking = NSRange(location: NSNotFound, length: 0) }
    }
    func selectedRange() -> NSRange { selection }
    func markedRange() -> NSRange { marking }
    func attributedSubstring(from range: NSRange) -> NSAttributedString! { NSAttributedString(string: text.substring(with: range)) }
    func length() -> Int { text.length }
    func characterIndex(for point: NSPoint, tracking mappingMode: IMKLocationToOffsetMappingMode, inMarkedRange: UnsafeMutablePointer<ObjCBool>!) -> Int { NSNotFound }
    func attributes(forCharacterIndex index: Int, lineHeightRectangle: UnsafeMutablePointer<NSRect>!) -> [AnyHashable: Any]! { [:] }
    func validAttributesForMarkedText() -> [Any]! { [NSAttributedString.Key.underlineStyle.rawValue] }
    func overrideKeyboard(withKeyboardNamed keyboardUniqueName: String!) {}
    func selectMode(_ modeIdentifier: String!) {}
    func supportsUnicode() -> Bool { true }
    func bundleIdentifier() -> String! { "org.shuntype.check-client" }
    func windowLevel() -> CGWindowLevel { 0 }
    func supportsProperty(_ property: TSMDocumentPropertyTag) -> Bool { false }
    func uniqueClientIdentifierString() -> String! { "ShunType-synthetic-client" }
    func string(from range: NSRange, actualRange: NSRangePointer!) -> String! {
        actualRange?.pointee = range
        return text.substring(with: range)
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer!) -> NSRect {
        actualRange?.pointee = range
        return .zero
    }
}

func checkInputAdapter() -> Bool {
    let client = CheckClient()
    let controller = InputSession()
    controller.activate(client)
    func key(_ code: UInt16, _ characters: String, flags: NSEvent.ModifierFlags = []) -> Bool {
        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                          timestamp: 0, windowNumber: 0, context: nil,
                                          characters: characters, charactersIgnoringModifiers: characters,
                                          isARepeat: false, keyCode: code) else { return false }
        return controller.processEvent(event, client: client)
    }
    for (code, characters) in [(1, "s"), (32, "u"), (20, "3"), (8, "c"), (37, "l"), (20, "3")] {
        guard key(UInt16(code), characters) else { return false }
    }
    guard client.text as String == "prefix 你好", client.marking.length == 2 else { return false }
    // Repeated activation must not throw away an existing composition.
    controller.activate(client)
    guard key(36, "\r"), client.text as String == "prefix 你好", client.marking.location == NSNotFound else { return false }
    guard !key(36, "\r"), !key(51, "\u{7f}") else { return false }
    guard key(1, "s"), key(32, "u"), key(53, "\u{1b}"), client.text as String == "prefix 你好su" else { return false }
    guard key(1, "s"), key(51, "\u{7f}"), client.text as String == "prefix 你好su", client.marking.location == NSNotFound else { return false }
    guard key(35, "p"), !key(8, "c", flags: .command), client.text as String == "prefix 你好sup" else { return false }
    guard key(1, "s") else { return false }
    controller.deactivate(client)
    guard client.text as String == "prefix 你好sups", client.marking.location == NSNotFound else { return false }
    print("Synthetic IMK client: Chinese marked text, commit, literal Esc, backspace, shortcut pass-through, activation and deactivation passed.")
    return true
}
