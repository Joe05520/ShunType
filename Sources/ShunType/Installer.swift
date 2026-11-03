import AppKit
import Carbon

enum Installer {
    static var directory: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods", isDirectory: true) }
    static var destination: URL { directory.appendingPathComponent("ShunTypeInputMethod.app", isDirectory: true) }
    static var isInstalled: Bool { FileManager.default.fileExists(atPath: destination.path) }

    @MainActor static func confirmAndInstall() -> String {
        guard let source = Bundle.main.url(forResource: "ShunTypeInputMethod", withExtension: "app") else { return "此建置沒有附上輸入法，請使用完整 DMG 版本。" }
        if isInstalled { return "已存在輸入法檔案。本預覽版不會覆寫；請先切回 ABC，依移除說明移除舊版後再安裝。" }
        let alert = NSAlert()
        alert.messageText = "新增順打輸入法？"
        alert.informativeText = "將複製到：\(destination.path)\n\n不會刪除或自動切換現有輸入法。接著請到鍵盤設定加入並選用。這是尚未公證的開發預覽版。"
        alert.addButton(withTitle: "安裝"); alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return "已取消，未安裝。" }
        let staging = directory.appendingPathComponent(".ShunType-\(UUID().uuidString).app")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: staging)
            try FileManager.default.moveItem(at: staging, to: destination)
            let status = TISRegisterInputSource(destination as CFURL)
            return status == noErr ? "已複製並要求 macOS 註冊。請開啟鍵盤設定加入「順打」；若未出現，請登出再登入。" : "已複製；macOS 註冊回傳 \(status)。請保留原輸入法，登出再登入後檢查鍵盤設定。"
        } catch {
            try? FileManager.default.removeItem(at: staging)
            return "安裝未完成：\(error.localizedDescription)"
        }
    }
    @MainActor static func openKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") { NSWorkspace.shared.open(url) }
    }
    @MainActor static func selectInputSource(_ identifier: String) -> String {
        let query = [kTISPropertyInputSourceID as String: identifier] as CFDictionary
        let sources = TISCreateInputSourceList(query, true).takeRetainedValue() as! [TISInputSource]
        guard let source = sources.first else { return "macOS 尚未列出這個輸入來源，請先在鍵盤設定加入。" }
        if identifier.contains("shuntype") {
            let alert = NSAlert()
            alert.messageText = "選用測試中的順打輸入法？"
            alert.informativeText = "本版已修正封裝與啟動錯誤，但尚未完成跨 App 實體鍵盤測試。請先在空白測試文件試用；若無法打字，從選單列切回原有輸入法，或返回本頁按「切回 ABC」。"
            alert.addButton(withTitle: "取消")
            alert.addButton(withTitle: "選用測試")
            guard alert.runModal() == .alertSecondButtonReturn else { return "未切換輸入法。" }
            let enabled = TISEnableInputSource(source)
            guard enabled == noErr else { return "無法啟用輸入來源（\(enabled)）。" }
        }
        let status = TISSelectInputSource(source)
        return status == noErr ? "已選用：\(identifier == "com.apple.keylayout.ABC" ? "ABC" : "順打")" : "切換未完成（\(status)）。"
    }
    @MainActor static func revealInputMethods() {
        if isInstalled { NSWorkspace.shared.activateFileViewerSelecting([destination]) }
        else if FileManager.default.fileExists(atPath: directory.path) { NSWorkspace.shared.open(directory) }
    }
    @MainActor static func openLicenses() {
        if let url = Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "txt") { NSWorkspace.shared.open(url) }
    }
}
