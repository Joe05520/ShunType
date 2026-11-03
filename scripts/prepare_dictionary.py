#!/usr/bin/env python3
"""Development-time only. Fetch a pinned MIT corpus and generate offline resources."""
from pathlib import Path
import hashlib, json, math, urllib.request

ROOT = Path(__file__).resolve().parents[1]
REV = "257da536ddaf590aae0e74e6adb9b415988344f6"
BASE = f"https://raw.githubusercontent.com/openvanilla/McBopomofo/{REV}/"
CACHE = ROOT / "work/upstream"
OUT = ROOT / "Sources/ShunTypeCore/Resources"
CACHE.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)

def fetch(path):
    dest = CACHE / Path(path).name
    if not dest.exists():
        with urllib.request.urlopen(BASE + path, timeout=60) as response:
            dest.write_bytes(response.read())
    return dest.read_text(encoding="utf-8")

files = ["Source/Data/BPMFBase.txt", "Source/Data/BPMFMappings.txt", "Source/Data/phrase.occ", "LICENSE.txt"]
texts = {p: fetch(p) for p in files}
for path, content in texts.items():
    print(path, len(content), content.splitlines()[:4])

freq = {}
for line in texts["Source/Data/phrase.occ"].splitlines():
    parts = line.split()
    if len(parts) >= 2:
        try: freq[parts[0]] = float(parts[1])
        except ValueError: pass

entries = {}
for path in files[:2]:
    for line in texts[path].splitlines():
        parts = line.split()
        if len(parts) < 2 or line.startswith("#"): continue
        word = parts[0]
        reading = "-".join(parts[1:]) if path.endswith("BPMFMappings.txt") else parts[1]
        if not all(c in "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙㄧㄨㄩㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦˊˇˋ˙-" for c in reading): continue
        if len(word) > 12 or len(reading.split("-")) != len(word): continue
        if not all("\u3400" <= c <= "\u9fff" for c in word): continue
        entries[(reading, word)] = max(1.0, freq.get(word, 1.0))

assert len(entries) > 50000, f"Unexpected dictionary format: {len(entries)}"
rows = [f"{reading}\t{word}\t{math.log10(count):.5f}" for (reading, word), count in sorted(entries.items())]
payload = "\n".join(rows) + "\n"
(OUT / "lexicon.tsv").write_text(payload, encoding="utf-8")
(OUT / "McBopomofo-LICENSE.txt").write_text(texts["LICENSE.txt"], encoding="utf-8")
provenance = {"repository":"https://github.com/openvanilla/McBopomofo", "revision":REV, "entries":len(entries), "generated_sha256":hashlib.sha256(payload.encode()).hexdigest(), "inputs":{p:hashlib.sha256((CACHE / Path(p).name).read_bytes()).hexdigest() for p in files}}
(OUT / "dictionary-source.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print(json.dumps(provenance, ensure_ascii=False, indent=2))
