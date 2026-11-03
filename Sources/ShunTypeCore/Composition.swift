import Foundation

public enum InputKey: Equatable, Sendable {
    case text(String), space, enter, escape, backspace, nextCandidate, previousCandidate, boundary
}

public struct CompositionUpdate: Sendable {
    public let consumed: Bool
    public let committed: String?
    public let marked: String
    public let raw: String
    public let analysis: Analysis
    public let selectedIndex: Int
    public init(consumed: Bool, committed: String?, marked: String, raw: String, analysis: Analysis, selectedIndex: Int) {
        self.consumed = consumed; self.committed = committed; self.marked = marked
        self.raw = raw; self.analysis = analysis; self.selectedIndex = selectedIndex
    }
}

/// All state belongs to one text-input session; no timers, global hooks or document rewrites.
public struct Composition {
    public private(set) var raw = ""
    public private(set) var selectedIndex = 0
    public var mode: InputMode = .automatic
    private let decoder: Decoder
    public init(decoder: Decoder = .shared, mode: InputMode = .automatic) { self.decoder = decoder; self.mode = mode }
    public var analysis: Analysis { decoder.analyze(raw, mode: mode) }
    public var rendered: String {
        let a = analysis
        return a.shouldConvert && !a.candidates.isEmpty ? a.candidates[min(selectedIndex, a.candidates.count - 1)].text : raw
    }

    public mutating func process(_ key: InputKey) -> CompositionUpdate {
        var committed: String?, consumed = true
        func update(_ text: String?, _ consumed: Bool) -> CompositionUpdate {
            CompositionUpdate(consumed: consumed, committed: text, marked: rendered, raw: raw, analysis: analysis, selectedIndex: selectedIndex)
        }
        switch key {
        case .text(let text):
            guard !text.isEmpty else { return update(nil, false) }
            // Literal input commits without depending on another active system IME.
            if mode == .english {
                committed = rendered + text; raw = ""; selectedIndex = 0
                return update(committed, true)
            }
            if text.count > 1 || text.unicodeScalars.contains(where: { $0.value > 127 }) {
                committed = rendered + text; raw = ""; selectedIndex = 0
                return update(committed, true)
            }
            guard let c = text.first, Decoder.keyMap[c.lowercased().first!] != nil || Decoder.tones[c] != nil || c.isASCII && c.isLetter || c.isNumber else {
                committed = rendered + text; raw = ""; selectedIndex = 0
                return update(committed, true)
            }
            if raw.count >= 96 { committed = rendered; raw = "" }
            raw += text; selectedIndex = 0
        case .space:
            guard !raw.isEmpty else { return update(nil, false) }
            if analysis.shouldConvert { committed = rendered; raw = "" }
            else if !decoder.isProtected(raw), decoder.parse(raw + " ") != nil, !raw.hasSuffix(" ") {
                raw += " "
            } else { committed = rendered; raw = ""; consumed = false }
            selectedIndex = 0
        case .enter:
            guard !raw.isEmpty else { return update(nil, false) }
            committed = rendered; raw = ""; selectedIndex = 0
        case .escape:
            guard !raw.isEmpty else { return update(nil, false) }
            committed = raw; raw = ""; selectedIndex = 0
        case .backspace:
            guard !raw.isEmpty else { return update(nil, false) }
            raw.removeLast(); selectedIndex = 0
        case .nextCandidate, .previousCandidate:
            let a = analysis
            guard a.shouldConvert, !a.candidates.isEmpty else {
                if !raw.isEmpty { committed = rendered; raw = "" }
                return update(committed, false)
            }
            let delta = key == .nextCandidate ? 1 : -1
            selectedIndex = (selectedIndex + delta + a.candidates.count) % a.candidates.count
        case .boundary:
            if !raw.isEmpty { committed = rendered; raw = "" }
            selectedIndex = 0; consumed = false
        }
        return update(committed, consumed)
    }

    public mutating func reset() { raw = ""; selectedIndex = 0 }
}
