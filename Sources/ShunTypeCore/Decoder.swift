import Foundation

public enum InputMode: String, CaseIterable, Codable, Sendable {
    case automatic, chinese, english
    public var title: String { switch self { case .automatic: return "自動中英"; case .chinese: return "注音優先"; case .english: return "純英文" } }
}

public struct Candidate: Equatable, Sendable {
    public let text: String
    public let score: Double
}

public struct Analysis: Sendable {
    public let raw: String
    public let reading: String
    public let candidates: [Candidate]
    public let shouldConvert: Bool
    public let reason: String
    public var best: String { shouldConvert ? candidates.first?.text ?? raw : raw }
}

public final class Decoder: @unchecked Sendable {
    public static let shared = Decoder()
    private struct Entry { let text: String; let score: Double }
    private var lexicon: [String: [Entry]] = [:]
    private var syllables: Set<String> = []
    public private(set) var entryCount = 0
    public private(set) var loadMilliseconds: Double = 0
    public var isReady: Bool { entryCount > 0 }

    public static let keyMap: [Character: Character] = Dictionary(uniqueKeysWithValues: zip(
        Array("1qaz2wsxedcrfv5tgbyhnujm8ik,9ol.0p;/-"),
        Array("ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙㄧㄨㄩㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ")
    ))
    public static let tones: [Character: Character] = ["6":"ˊ", "3":"ˇ", "4":"ˋ", "7":"˙"]
    private static let initials = Set("ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ")
    private static let medials = Set("ㄧㄨㄩ")
    private static let finals = Set("ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ")
    private static let english = Set(("a i an am as at be by do go he hi if in is it me my no of ok on or so to up us we yes " +
        "hello world thanks thank you good great nice test tests testing code coding git github npm npx node js ts swift python rust cargo " +
        "read write open close save undo redo app apps mac macos windows linux apple google chrome safari line word excel email " +
        "the this that these those and but for from with without not can could would should have has had was were are will " +
        "please help fix build run install update remove commit push pull merge branch main master dev debug release version " +
        "api http https ssh url json yaml html css sql null nil true false let var func class return print console log error " +
        "file files folder path home user users documents desktop downloads config package input output src bin lib readme " +
        "login logout password token key keys secret admin sudo brew curl wget docker kubectl k8s python3 nodejs utf8 utf-8 " +
        "vscode xcode github.com example.com localhost date time now today tomorrow monday tuesday wednesday friday " +
        "data model ai llm gpt chatgpt claude chat message send select copy paste clear settings function async await " +
        "one two three four five six seven eight nine ten twenty thirty forty fifty hundred zero red green blue " +
        "about above after again all also any back because before between both change come day down each even every first " +
        "get give how into just know last like little long look make many more most much must name need new next only " +
        "other our out over part people right same say see she some take than their them then there they thing think " +
        "through too under use very want way well what when where which who why work your abc abcd abcd1234 qwerty").split(separator: " ").map(String.init))

    public init(url: URL? = nil) {
        let start = Date.timeIntervalSinceReferenceDate
        let file = url ?? Bundle.module.url(forResource: "lexicon", withExtension: "tsv")
        if let file, let text = try? String(contentsOf: file, encoding: .utf8) {
            for line in text.split(separator: "\n") {
                let fields = line.split(separator: "\t")
                guard fields.count == 3, let frequency = Double(fields[2]) else { continue }
                let reading = String(fields[0])
                lexicon[reading, default: []].append(Entry(text: String(fields[1]), score: frequency - 7.5))
                for s in reading.split(separator: "-") { syllables.insert(String(s)) }
                entryCount += 1
            }
            for key in Array(lexicon.keys) {
                lexicon[key]!.sort { $0.score == $1.score ? $0.text < $1.text : $0.score > $1.score }
                lexicon[key] = Array(lexicon[key]!.prefix(6))
            }
        }
        loadMilliseconds = (Date.timeIntervalSinceReferenceDate - start) * 1000
    }

    public func isProtected(_ text: String) -> Bool {
        let s = text.trimmingCharacters(in: .whitespaces)
        if Self.english.contains(s.lowercased()) { return true }
        if s.contains(where: { $0.isUppercase }) { return true }
        if s.contains(":") || s.contains("@") || s.contains("_") || s.contains("\\") { return true }
        if s.hasPrefix("/") || s.hasPrefix("./") || s.hasPrefix("../") || s.hasPrefix("~") || s.hasPrefix("--") { return true }
        if s.range(of: #"\.[a-zA-Z]{1,8}$"#, options: .regularExpression) != nil { return true }
        if s.range(of: #"^[0-9.,:/-]+$"#, options: .regularExpression) != nil { return true }
        if s.range(of: #"^(v?\d+\.){1,}\d+$"#, options: .regularExpression) != nil { return true }
        if s.contains(" ") && s.split(separator: " ").contains(where: { Self.english.contains(String($0).lowercased()) }) { return true }
        return false
    }

    public func analyze(_ raw: String, mode: InputMode = .automatic) -> Analysis {
        func unchanged(_ reason: String, _ reading: String = "", _ candidates: [Candidate] = []) -> Analysis {
            Analysis(raw: raw, reading: reading, candidates: candidates, shouldConvert: false, reason: reason)
        }
        guard !raw.isEmpty else { return unchanged("開始打字即可") }
        guard mode != .english else { return unchanged("純英文模式：保留原文") }
        guard raw.count <= 96 else { return unchanged("字串較長，保留原文") }
        guard isReady else { return unchanged("詞庫未載入，保留原文") }
        if mode == .automatic && isProtected(raw) { return unchanged("英文或技術字串：保留原文") }
        guard let parsed = parse(raw.lowercased()) else { return unchanged("尚未構成完整注音，保留原文") }
        let reading = parsed.joined(separator: "-")
        let choices = decode(parsed)
        guard !choices.isEmpty else { return unchanged("找不到完整詞句，保留原文", reading) }
        if mode == .chinese { return Analysis(raw: raw, reading: reading, candidates: choices, shouldConvert: true, reason: "注音優先：可按 Esc 保留英數原文") }
        let explicit = raw.contains(where: { Self.tones[$0] != nil })
        let structural = raw.contains(where: { $0.isNumber }) && raw.contains(" ")
        // A single syllable can easily be a product ID (e.g. cl3); automatic mode is deliberately conservative.
        let toneCount = raw.filter { Self.tones[$0] != nil }.count
        let tailComplete = raw.last.map { Self.tones[$0] != nil || $0 == " " } ?? false
        // Don't turn a partly typed second syllable into its first-tone homophone.
        // A longer sentence with two explicit tones may contain an unmarked final first tone (e.g. 嗎).
        let accepted = parsed.count >= 2 && (explicit || structural) && (tailComplete || parsed.count >= 3 && toneCount >= 2)
        return Analysis(raw: raw, reading: reading, candidates: choices, shouldConvert: accepted,
                        reason: accepted ? "辨識為注音 · Enter 確認，Esc 留原文" : "有歧義，先保留英數 · 可切到注音優先")
    }

    public func parse(_ raw: String) -> [String]? {
        var result: [String] = [], buffer = ""
        var lastGroup = -1
        func valid(_ s: String) -> Bool { syllables.contains(s) }
        for c in raw {
            if let tone = Self.tones[c] {
                guard !buffer.isEmpty, valid(buffer + String(tone)) else { return nil }
                result.append(buffer + String(tone)); buffer = ""; lastGroup = -1
            } else if c == " " {
                guard !buffer.isEmpty, valid(buffer) else { return nil }
                result.append(buffer); buffer = ""; lastGroup = -1
            } else if let phonetic = Self.keyMap[c] {
                let group = Self.initials.contains(phonetic) ? 0 : Self.medials.contains(phonetic) ? 1 : 2
                guard group > lastGroup else { return nil }
                buffer.append(phonetic); lastGroup = group
            } else { return nil }
        }
        if !buffer.isEmpty {
            guard valid(buffer) else { return nil }
            result.append(buffer)
        }
        return result.isEmpty ? nil : result
    }

    private func decode(_ syllables: [String]) -> [Candidate] {
        let count = syllables.count
        var lattice = Array(repeating: [Candidate](), count: count + 1)
        lattice[0] = [Candidate(text: "", score: 0)]
        for start in 0..<count where !lattice[start].isEmpty {
            var key = ""
            for end in start..<min(count, start + 12) {
                key += (end == start ? "" : "-") + syllables[end]
                guard let entries = lexicon[key] else { continue }
                for prefix in lattice[start] {
                    for entry in entries {
                        lattice[end + 1].append(Candidate(text: prefix.text + entry.text, score: prefix.score + entry.score))
                    }
                }
                var seen: Set<String> = []
                lattice[end + 1].sort { $0.score == $1.score ? $0.text < $1.text : $0.score > $1.score }
                lattice[end + 1] = Array(lattice[end + 1].filter { seen.insert($0.text).inserted }.prefix(6))
            }
        }
        return lattice[count]
    }

    /// Batch recovery preserves separators, non-ASCII text, punctuation, and protected tokens.
    public func recover(_ text: String, mode: InputMode = .automatic) -> String {
        guard mode != .english, !text.isEmpty else { return text }
        let pattern = #"https?://[^\s]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|(?:\.?\.?/|~/)[^\s]+|[A-Za-z0-9_.,;/\\:-]+|\s+|[^A-Za-z0-9_.,;/\\:\s-]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        let parts = regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
        // Never drop characters if the tokenizer has an unexpected gap.
        guard parts.joined() == text else { return text }
        var output = "", i = 0
        while i < parts.count {
            let part = parts[i]
            if part.first?.isASCII == true, part.first?.isWhitespace == false, !(mode == .automatic && isProtected(part)) {
                var joined = part, best: (Int, String)?
                let first = analyze(joined, mode: mode)
                if first.shouldConvert { best = (i + 1, first.best) }
                var j = i
                while j + 2 < parts.count, parts[j + 1] == " ", j < i + 12 {
                    let next = parts[j + 2]
                    if mode == .automatic && isProtected(next) { break }
                    joined += " " + next
                    let a = analyze(joined, mode: mode)
                    if a.shouldConvert { best = (j + 3, a.best) }
                    j += 2
                }
                if let best { output += best.1; i = best.0; continue }
            }
            output += part; i += 1
        }
        return output
    }
}
