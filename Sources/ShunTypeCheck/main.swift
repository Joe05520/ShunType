import Foundation
import ShunTypeCore

let decoder = Decoder.shared
if CommandLine.arguments.count > 1 {
    for raw in CommandLine.arguments.dropFirst() {
        let result = decoder.analyze(raw)
        print("\(raw) → \(result.best) | \(result.reading) | \(result.reason)")
        print(result.candidates.map(\.text).joined(separator: " / "))
    }
} else {
    let corpus = ["su3cl3", "su3cl3a8", "5j/ eji6", "rup wu0", "hk4g4", "dk3u3", "hello", "npm", "k8s", "python3", "2026-11-03", "https://github.com", "config.py"]
    var timings: [Double] = []
    for _ in 0..<30 {
        for raw in corpus {
            let start = DispatchTime.now().uptimeNanoseconds
            _ = decoder.analyze(raw)
            timings.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        }
    }
    timings.sort()
    let result: [String: Any] = [
        "version": "0.1.0-preview.1", "dictionaryEntries": decoder.entryCount,
        "coldLoadMilliseconds": decoder.loadMilliseconds,
        "warmDecodeP50Milliseconds": timings[timings.count / 2],
        "warmDecodeP95Milliseconds": timings[Int(Double(timings.count) * 0.95)],
        "warmDecodeMaxMilliseconds": timings.last!, "samples": timings.count,
        "fixtures": corpus.map { raw -> [String: Any] in
            let a = decoder.analyze(raw)
            return ["input": raw, "output": a.best, "converted": a.shouldConvert, "candidates": a.candidates.map(\.text)]
        },
        "scope": "Core decoder benchmark only. Not system IMK or cross-app acceptance."
    ]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    print(String(decoding: data, as: UTF8.self))
}
