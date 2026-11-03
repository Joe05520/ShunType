#!/usr/bin/env python3
from pathlib import Path
import hashlib, json
resources = Path(__file__).resolve().parents[1] / "Sources/ShunTypeCore/Resources"
info = json.loads((resources / "dictionary-source.json").read_text())
data = (resources / "lexicon.tsv").read_bytes()
assert hashlib.sha256(data).hexdigest() == info["generated_sha256"]
assert len(data.splitlines()) == info["entries"]
assert (resources / "McBopomofo-LICENSE.txt").stat().st_size > 1000
print(f"Verified {info['entries']} pinned dictionary entries and SHA-256.")
