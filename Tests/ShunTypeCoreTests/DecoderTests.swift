import XCTest
@testable import ShunTypeCore

final class DecoderTests: XCTestCase {
    let decoder = Decoder.shared

    func testDictionaryIsActuallyBundled() {
        XCTAssertGreaterThan(decoder.entryCount, 150_000)
        XCTAssertEqual(Decoder.keyMap.count, 37)
        XCTAssertEqual(Decoder.keyMap["s"], "ㄋ")
        XCTAssertEqual(Decoder.keyMap["u"], "ㄧ")
        XCTAssertEqual(Decoder.keyMap["/"], "ㄥ")
    }

    func testPhysicalKeysAreIndependentOfActiveSystemIME() {
        XCTAssertEqual(PhysicalKeyboard.text(keyCode: 1, fallback: "ㄋ", shift: false, capsLock: false), "s")
        XCTAssertEqual(PhysicalKeyboard.text(keyCode: 32, fallback: "ㄧ", shift: false, capsLock: false), "u")
        XCTAssertEqual(PhysicalKeyboard.text(keyCode: 20, fallback: "ˇ", shift: false, capsLock: false), "3")
        XCTAssertEqual(PhysicalKeyboard.text(keyCode: 1, fallback: "ㄋ", shift: true, capsLock: false), "S")
        XCTAssertEqual(PhysicalKeyboard.text(keyCode: 20, fallback: "ˇ", shift: true, capsLock: false), "#")
    }

    func testChineseRecovery() {
        let cases = ["su3cl3": "你好", "su3cl3a8": "你好嗎", "5j/ eji6": "中國", "hk4g4": "測試", "dk3u3": "可以", "2/3u vu84": "等一下"]
        for (raw, expected) in cases {
            let a = decoder.analyze(raw)
            XCTAssertTrue(a.shouldConvert, raw)
            XCTAssertEqual(a.best, expected, raw)
        }
    }

    func testAdditionalEverydayVocabulary() {
        let cases = [
            "vu,4vu,4": "謝謝", "au/6wu0 ru04": "明天見", "w961o3": "台北",
            "vup 5j6": "新竹", "2u04sl3": "電腦", "gj bj4": "輸入",
            "5j/ jp6": "中文", "u/ jp6": "英文", "jp4wu6": "問題",
            "d9 m06": "開源", "t/6g4": "程式", "g3m/4": "使用",
            "y xul4": "資料", "j06t/6": "完成", "vul4xm4": "效率",
            "vu84j3": "下午", "yl30 ": "早安", "j030 ": "晚安",
            "y94ru04": "再見", "1j4cl3u4n7": "不好意思", "ao6ej0 vu4": "沒關係"
        ]
        for (raw, expected) in cases {
            let a = decoder.analyze(raw)
            XCTAssertTrue(a.shouldConvert, raw)
            XCTAssertTrue(a.candidates.map(\.text).contains(expected), "\(raw): \(a.candidates.map(\.text))")
        }
    }

    func testProtectedEnglishAndIdentifiers() {
        let cases = ["hello", "world", "git", "npm", "node", "python3", "k8s", "utf-8", "UTF-8", "npm run dev", "config.py", "README.md", "/Users/test/file", "./src/main.swift", "foo_bar", "user@example.com", "https://github.com/a/b", "192.168.1.1", "2026-11-03", "123456", "fooBar", "ABC123", "v1.2.3", "--help", "cl3", "l3"]
        for raw in cases { XCTAssertEqual(decoder.analyze(raw).best, raw, raw) }
    }

    func testMixedRecoveryRetainsWhitespaceAndPunctuation() {
        XCTAssertEqual(decoder.recover("hello su3cl3！\n  npm run dev"), "hello 你好！\n  npm run dev")
        XCTAssertEqual(decoder.recover("測試：5j/ eji6 / config.py"), "測試：中國 / config.py")
        XCTAssertEqual(decoder.recover("https://example.com/su3cl3 user@su3cl3.com"), "https://example.com/su3cl3 user@su3cl3.com")
    }

    func testExplicitModesAndBoundedWork() {
        XCTAssertEqual(decoder.analyze("su3", mode: .chinese).best, "你")
        XCTAssertEqual(decoder.analyze("su3cl3", mode: .english).best, "su3cl3")
        let long = String(repeating: "su3cl3", count: 100)
        XCTAssertEqual(decoder.analyze(long).best, long)
        XCTAssertNil(decoder.parse("ssu3"))
        XCTAssertNil(decoder.parse("su33"))
        XCTAssertEqual(decoder.parse("5j/ eji6"), ["ㄓㄨㄥ", "ㄍㄨㄛˊ"])
    }

    func testLiteralModeAndPunctuationDoNotLeakToOtherIME() {
        var session = Composition(mode: .english)
        let letter = session.process(.text("s"))
        XCTAssertTrue(letter.consumed)
        XCTAssertEqual(letter.committed, "s")
        session.mode = .automatic
        for c in "su3cl3" { _ = session.process(.text(String(c))) }
        let punctuation = session.process(.text("!"))
        XCTAssertTrue(punctuation.consumed)
        XCTAssertEqual(punctuation.committed, "你好!")
        XCTAssertEqual(session.raw, "")
    }

    func testMissingDictionaryFailsOpen() {
        let unavailable = Decoder(url: URL(fileURLWithPath: "/nonexistent/shuntype.tsv"))
        XCTAssertFalse(unavailable.isReady)
        XCTAssertEqual(unavailable.recover("su3cl3"), "su3cl3")
    }

    func testCommitAndEnterNeverSendForUser() {
        var session = Composition()
        for c in "su3cl3" { _ = session.process(.text(String(c))) }
        XCTAssertEqual(session.rendered, "你好")
        let commit = session.process(.enter)
        XCTAssertEqual(commit.committed, "你好")
        XCTAssertTrue(commit.consumed)
        XCTAssertEqual(commit.marked, "")
        XCTAssertFalse(session.process(.enter).consumed)
    }

    func testEscapeRestoresLiteralKeys() {
        var session = Composition()
        for c in "su3cl3a8" { _ = session.process(.text(String(c))) }
        XCTAssertEqual(session.process(.escape).committed, "su3cl3a8")
        XCTAssertEqual(session.raw, "")
    }

    func testFirstToneSpaceAndEnglishWordBoundary() {
        var session = Composition()
        for c in "5j/" { _ = session.process(.text(String(c))) }
        XCTAssertTrue(session.process(.space).consumed)
        for c in "eji6" { _ = session.process(.text(String(c))) }
        XCTAssertEqual(session.process(.enter).committed, "中國")
        for c in "hello" { _ = session.process(.text(String(c))) }
        let result = session.process(.space)
        XCTAssertEqual(result.committed, "hello")
        XCTAssertFalse(result.consumed)
    }

    func testBackspaceCandidateCyclingAndFocusBoundary() {
        var session = Composition()
        for c in "su3cl3" { _ = session.process(.text(String(c))) }
        let first = session.rendered
        _ = session.process(.nextCandidate)
        XCTAssertNotEqual(session.rendered, first)
        _ = session.process(.previousCandidate)
        XCTAssertEqual(session.rendered, first)
        _ = session.process(.backspace)
        XCTAssertEqual(session.raw, "su3cl")
        XCTAssertEqual(session.process(.boundary).committed, "su3cl")
        XCTAssertFalse(session.process(.backspace).consumed)
    }

    func testLiteralConservationAcrossRandomEvents() {
        var state: UInt64 = 42
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789,./;-")
        for _ in 0..<200 {
            var original = "", session = Composition(), emitted = ""
            for _ in 0..<80 {
                state = state &* 6364136223846793005 &+ 1
                if state % 9 == 0, !original.isEmpty {
                    original.removeLast(); _ = session.process(.backspace)
                } else {
                    let char = String(alphabet[Int(state % UInt64(alphabet.count))])
                    original += char
                    if let commit = session.process(.text(char)).committed { emitted += commit }
                }
            }
            emitted += session.process(.escape).committed ?? ""
            XCTAssertEqual(emitted, original)
        }
    }
}
