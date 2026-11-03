#!/usr/bin/env python3
"""Build a self-contained .app and a GitHub Releases-ready DMG. No machine installation."""
from pathlib import Path
import argparse, hashlib, json, os, platform, plistlib, shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.1.0-preview.2"
ARCH = platform.machine()
assert ARCH in ("arm64", "x86_64"), f"Unsupported build host: {ARCH}"
parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=ROOT / "outputs")
parser.add_argument("--skip-build", action="store_true")
args = parser.parse_args()
OUT = args.output.resolve()
OUT.mkdir(parents=True, exist_ok=True)
WORK = ROOT / "work/package"
WORK.mkdir(parents=True, exist_ok=True)

def run(*parts, **kwargs):
    return subprocess.run(list(map(str, parts)), cwd=ROOT, check=True, **kwargs)

if not args.skip_build:
    run("swift", "build", "-c", "release")
binary = Path(subprocess.check_output(["swift", "build", "-c", "release", "--show-bin-path"], cwd=ROOT, text=True).strip())
iconset = WORK / "ShunType.iconset"
run("swift", ROOT / "scripts/draw_icon.swift", iconset)
run("iconutil", "-c", "icns", iconset, "-o", WORK / "ShunType.icns")

notices = (ROOT / "LICENSE").read_text() + "\n\n--- McBopomofo dictionary data ---\n" + (ROOT / "Sources/ShunTypeCore/Resources/McBopomofo-LICENSE.txt").read_text()
notices += "\nSource: https://github.com/openvanilla/McBopomofo\nPinned revision and data hashes: dictionary-source.json in the resource bundle.\nNo upstream source code or UI is copied into the executable.\n"

def make_bundle(path, executable, identifier, name, input_method=False):
    if path.exists(): shutil.rmtree(path)
    contents = path / "Contents"
    macos = contents / "MacOS"; resources = contents / "Resources"
    macos.mkdir(parents=True); resources.mkdir()
    shutil.copy2(binary / executable, macos / executable)
    shutil.copytree(binary / "ShunType_ShunTypeCore.bundle", resources / "ShunType_ShunTypeCore.bundle")
    shutil.copy2(WORK / "ShunType.icns", resources / "ShunType.icns")
    shutil.copy2(WORK / "InputMenu.tiff", resources / "InputMenu.tiff")
    (resources / "THIRD_PARTY_NOTICES.txt").write_text(notices)
    info = {
        "CFBundleName": name, "CFBundleDisplayName": name,
        "CFBundleExecutable": executable, "CFBundleIdentifier": identifier,
        "CFBundlePackageType": "APPL", "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "3",
        "CFBundleIconFile": "ShunType", "LSMinimumSystemVersion": "14.0",
        "NSHighResolutionCapable": True, "NSPrincipalClass": "NSApplication",
        "NSHumanReadableCopyright": "Copyright © 2026 ShunType contributors. MIT License.",
        "LSApplicationCategoryType": "public.app-category.utilities"
    }
    if input_method:
        info.update({
            "LSUIElement": True,
            "InputMethodConnectionName": "ShunType_Connection",
            "InputMethodServerControllerClass": "ShunTypeInputController",
            "TISInputSourceID": identifier, "TISIntendedLanguage": "zh-Hant",
            "tsInputMethodCharacterRepertoireKey": ["Hant", "Latn"],
            "tsInputMethodIconFileKey": "InputMenu.tiff",
            "TISParticipatesInTouchBar": False
        })
    with (contents / "Info.plist").open("wb") as f: plistlib.dump(info, f)
    (contents / "PkgInfo").write_bytes(b"APPL????")
    return resources

app = OUT / "ShunType.app"
resources = make_bundle(app, "ShunType", "org.shuntype.studio", "順打 ShunType")
ime = resources / "ShunTypeInputMethod.app"
make_bundle(ime, "ShunTypeInputMethod", "org.shuntype.inputmethod.ShunType", "順打", input_method=True)

identity = os.environ.get("SHUNTYPE_SIGN_IDENTITY", "-")
for target in [ime, app]:
    command = ["codesign", "--force", "--sign", identity]
    if identity != "-": command += ["--options", "runtime", "--timestamp"]
    run(*command, target)
    run("codesign", "--verify", "--deep", "--strict", target)

# Check the actual signed, packaged binaries; compilation alone did not catch a
# missing input-method Info.plist or the macOS 27 IMK startup crash.
run(ime / "Contents/MacOS/ShunTypeInputMethod", "--self-check", timeout=20)
run(app / "Contents/MacOS/ShunType", "--self-check", timeout=20)

stage = WORK / "dmg-stage"
if stage.exists(): shutil.rmtree(stage)
stage.mkdir()
shutil.copytree(app, stage / app.name)
(stage / "Applications").symlink_to("/Applications", target_is_directory=True)
guide = """順打 ShunType 0.1 開發預覽

1. 把 ShunType.app 拖到 Applications（應用程式）。
2. 開啟順打，在「注音試打」輸入文字。使用內附詞庫，不需額外安裝工具。
3. 原生輸入法仍在驗證中，日常使用請先保留原本輸入法。

本預覽包採本機 ad-hoc 簽署，尚未經 Apple 公證。從網路下載後，Gatekeeper 可能阻擋。
若系統不允許開啟，請等待 Developer ID 簽署與公證版本；不需關閉系統安全防護。

macOS 14+；此包為 Apple Silicon（arm64）。Intel 版本尚未提供。
此包不是已通過所有 App 測試的穩定版。
舊預覽版曾因封裝與啟動錯誤而無法打字。本包已修正這兩處錯誤，
並通過封裝啟動與模擬文字框測試；跨 App 的實體鍵盤驗收仍未完成。
沒有安裝輸入法時，只有 App 內試打與還原文字可用。
順打需成為目前輸入法才能處理輸入；切到 ABC 時不會處理。

試打按鍵：su3cl3 → 你好；su3cl3a8 → 你好嗎。
Enter 確認組字；Esc 保留原始英數；↓ / Tab 換候選。
單音節或有歧義時可選「注音優先」。

開源碼與詞庫授權：App 內「安裝與說明」→「查看開源授權」。
"""
guide = guide.replace("此包為 Apple Silicon（arm64）。Intel 版本尚未提供。", f"此包架構為 {ARCH}；僅在本機架構建置，不是 Universal 包。")
(stage / "開始使用.txt").write_text(guide)
(OUT / "開始使用.txt").write_text(guide)
dmg = OUT / f"ShunType-{VERSION}-macOS-{ARCH}.dmg"
if dmg.exists(): dmg.unlink()
run("hdiutil", "create", "-volname", "順打 ShunType", "-srcfolder", stage, "-ov", "-format", "UDZO", dmg)
run("hdiutil", "verify", dmg)
digest = hashlib.sha256(dmg.read_bytes()).hexdigest()
(OUT / "SHA256SUMS.txt").write_text(f"{digest}  {dmg.name}\n")
metadata = {"version":VERSION,"architecture":ARCH,"minimumMacOS":"14.0","signing":"ad-hoc" if identity == "-" else "Developer ID requested; inspect codesign separately", "notarized":False, "dmg":dmg.name,"sha256":digest,"bytes":dmg.stat().st_size}
(OUT / "build-manifest.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2)+"\n")
print(json.dumps(metadata, ensure_ascii=False, indent=2))
