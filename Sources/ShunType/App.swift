import SwiftUI
import AppKit
import ShunTypeCore

@main
struct ShunTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    init() {
        if CommandLine.arguments.contains("--self-check") {
            let decoder = Decoder.shared
            let passed = decoder.entryCount == 171126 && decoder.analyze("su3cl3").best == "你好" && decoder.analyze("python3").best == "python3"
            let report: [String: Any] = ["passed": passed, "bundledEntries": decoder.entryCount, "chinese": decoder.analyze("su3cl3").best, "english": decoder.analyze("python3").best, "networkRequired": false]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), let string = String(data: data, encoding: .utf8) { print(string) }
            exit(passed ? 0 : 1)
        }
    }
    var body: some Scene {
        WindowGroup("順打 ShunType") { ContentView().frame(minWidth: 900, minHeight: 690) }
            .defaultSize(width: 1080, height: 790)
            .commands { CommandGroup(replacing: .newItem) {} }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@MainActor
final class StudioModel: ObservableObject {
    @Published var mode: InputMode = .automatic
    @Published var raw = ""
    @Published var marked = ""
    @Published var reading = ""
    @Published var reason = "直接打字，順打會在這個試打區判斷中英文。"
    @Published var candidates: [String] = []
    @Published var selected = 0
    @Published var document = ""
    @Published var commandID = 0
    var demo = ""
    @Published var recoveryInput = "你好，請幫我 hk4g4 一下。\nhello su3cl3！\n5j/ eji6\n保留原文：npm run dev / config.py / k8s"
    @Published var recoveryOutput = ""
    @Published var isRecovering = false
    @Published var recoveryStatus = ""
    @Published var installMessage = ""
    let decoder = Decoder.shared
    func sample(_ keys: String) { demo = keys; commandID += 1 }
    func receive(_ update: CompositionUpdate, document: String) {
        raw = update.raw; marked = update.marked; reading = update.analysis.reading
        candidates = update.analysis.shouldConvert ? update.analysis.candidates.map(\.text) : []
        selected = update.selectedIndex; reason = update.analysis.reason; self.document = document
    }
    func recover() {
        guard !isRecovering else { return }
        let input = recoveryInput, currentMode = mode, engine = decoder
        isRecovering = true; recoveryStatus = ""
        Task {
            let result = await Task.detached(priority: .userInitiated) { engine.recover(input, mode: currentMode) }.value
            isRecovering = false
            if recoveryInput == input && mode == currentMode { recoveryOutput = result }
            else { recoveryStatus = "文字或模式已變更，請重新按還原。" }
        }
    }
}

private enum Page: String, CaseIterable, Identifiable {
    case type = "試打", recover = "還原文字", setup = "安裝與說明"
    var id: String { rawValue }
    var symbol: String { switch self { case .type: return "keyboard"; case .recover: return "text.badge.checkmark"; case .setup: return "slider.horizontal.3" } }
}

struct ContentView: View {
    @StateObject private var model = StudioModel()
    @State private var page = Page.type
    private let ink = Color(red: 0.10, green: 0.22, blue: 0.22)
    private let accent = Color(red: 0.05, green: 0.46, blue: 0.39)
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 12) {
                    Image(systemName: "character.cursor.ibeam").font(.system(size: 24, weight: .semibold))
                        .frame(width: 47, height: 47).foregroundStyle(.white).background(accent, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("順打").font(.system(size: 24, weight: .bold))
                        Text("SHUNTYPE").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                    }
                }
                VStack(spacing: 7) {
                    ForEach(Page.allCases) { item in
                        Button { page = item } label: {
                            Label(item.rawValue, systemImage: item.symbol).font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 12)
                                .background(page == item ? accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(page == item ? accent : ink.opacity(0.7))
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 9) {
                    Label("輸入只留在本機", systemImage: "lock.shield").font(.system(size: 12, weight: .medium))
                    Text("不需帳號，也不需網路。\n試打不會接管其他 App。").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                    Divider().padding(.vertical, 7)
                    Text("0.1.0 · 開發預覽").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
            }.padding(24).frame(width: 212).background(Color(red: 0.93, green: 0.96, blue: 0.94))
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    HStack {
                        Label("標準注音 · 繁體中文", systemImage: "circle.grid.2x2").font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        Label(model.decoder.isReady ? "詞庫已就緒" : "詞庫未載入", systemImage: model.decoder.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(model.decoder.isReady ? accent : .orange)
                    }
                    switch page {
                    case .type: typePage
                    case .recover: recoveryPage
                    case .setup: setupPage
                    }
                }.padding(34).frame(maxWidth: 1040)
            }.background(Color(red: 0.975, green: 0.98, blue: 0.97))
        }
        .tint(accent).foregroundStyle(ink).preferredColorScheme(.light)
    }

    private var modePicker: some View {
        Picker("輸入模式", selection: $model.mode) { ForEach(InputMode.allCases, id: \.self) { Text($0.title).tag($0) } }
            .pickerStyle(.segmented).labelsHidden().frame(width: 290)
    }

    private var typePage: some View {
        VStack(alignment: .leading, spacing: 23) {
            VStack(alignment: .leading, spacing: 9) {
                Text("少切換，順著打。").font(.system(size: 34, weight: .bold))
                Text("直接打注音按鍵或英文，在這裡體驗自動中英組字。").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("試打區", systemImage: "pencil.line").font(.system(size: 13, weight: .semibold))
                    Spacer(); modePicker
                }.padding(18)
                Divider()
                ZStack(alignment: .topLeading) {
                    if model.document.isEmpty && model.raw.isEmpty {
                        Text("點這裡開始打字…\n例如：su3cl3 → 你好").font(.system(size: 21)).foregroundStyle(.tertiary).padding(20).allowsHitTesting(false)
                    }
                    LiveEditor(model: model).frame(height: 205).accessibilityIdentifier("live-editor")
                }
                Divider()
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "sparkle").foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.reason).font(.system(size: 12)).foregroundStyle(.secondary)
                        if !model.candidates.isEmpty {
                            ScrollView(.horizontal) { HStack(spacing: 8) {
                                ForEach(Array(model.candidates.prefix(5).enumerated()), id: \.offset) { index, candidate in
                                    Text(candidate).font(.system(size: 15, weight: index == model.selected ? .semibold : .regular))
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(index == model.selected ? accent.opacity(0.12) : Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                                }
                            } }.scrollIndicators(.hidden)
                        }
                    }
                    Spacer(minLength: 0)
                    Button("清空") { model.sample("") }.buttonStyle(.borderless).font(.system(size: 12))
                }.padding(17).frame(minHeight: 64)
            }.background(.white, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(ink.opacity(0.09)))
            HStack(spacing: 8) {
                Text("試試看").font(.system(size: 12)).foregroundStyle(.secondary)
                sampleButton("你好嗎", "su3cl3a8")
                sampleButton("中國", "5j/ eji6")
                sampleButton("保留英文", "python3")
                sampleButton("測試", "hk4g4")
            }
            HStack(alignment: .top, spacing: 24) {
                hint("return", "Enter 確認", "組字時只確認文字，\n不會替你送出訊息。")
                hint("escape", "Esc 留原文", "猜錯了，就保留\n原來的英數按鍵。")
                hint("arrow.down", "↓ / Tab 換候選", "有歧義時用熟悉的\n選字操作修正。")
            }.padding(.top, 4)
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                Text("這是 App 內試打。要在其他程式使用，請到「安裝與說明」啟用原生輸入法。")
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(14)
                .background(accent.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func sampleButton(_ title: String, _ keys: String) -> some View {
        Button(title) { model.sample(keys) }.buttonStyle(.bordered).controlSize(.small)
    }
    private func hint(_ icon: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold))
            Text(text).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recoveryPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("已經打錯，也救得回來。").font(.system(size: 30, weight: .bold))
            Text("貼入文字後按還原。結果留在這個 App，不會自動覆寫其他程式。").font(.system(size: 13)).foregroundStyle(.secondary)
            modePicker
            Text("原始文字").font(.system(size: 13, weight: .semibold))
            TextEditor(text: $model.recoveryInput).font(.system(size: 17)).padding(10).frame(height: 170)
                .background(.white, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(ink.opacity(0.1)))
                .accessibilityIdentifier("recovery-input")
            HStack {
                Button(model.isRecovering ? "還原中…" : "還原文字", systemImage: "arrow.down") { model.recover() }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.isRecovering)
                Spacer()
                Text("保守判斷 · 不確定就保留原文").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack {
                Text("還原結果").font(.system(size: 13, weight: .semibold)); Spacer()
                Button("複製結果", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.recoveryOutput, forType: .string)
                }.disabled(model.recoveryOutput.isEmpty)
            }
            TextEditor(text: $model.recoveryOutput).font(.system(size: 17)).padding(10).frame(height: 170)
                .background(.white, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(ink.opacity(0.1)))
                .accessibilityIdentifier("recovery-output")
            Text("同音字仍可能選錯，請確認結果。只有按下「複製結果」才會寫入剪貼簿。").font(.system(size: 11)).foregroundStyle(.secondary)
            if !model.recoveryStatus.isEmpty { Text(model.recoveryStatus).font(.system(size: 12)).foregroundStyle(.secondary) }
        }
    }

    private var setupPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("從試打，到日常輸入。").font(.system(size: 30, weight: .bold))
            Text("先確認手感，再由你決定是否安裝原生輸入法。").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 18) {
                Label(Installer.isInstalled ? "已找到輸入法檔案" : "尚未安裝系統輸入法", systemImage: Installer.isInstalled ? "checkmark.circle" : "circle.dashed").font(.headline)
                Text("1　建議先把「順打」拖到「應用程式」，再開啟。\n2　按下安裝，只會新增「順打輸入法」，不刪除原有輸入法。\n3　到鍵盤設定加入「順打」，再從選單列選用。").font(.system(size: 13)).lineSpacing(8)
                HStack {
                    Button("安裝順打輸入法…") { model.installMessage = Installer.confirmAndInstall() }.buttonStyle(.borderedProminent)
                    Button("開啟鍵盤設定") { Installer.openKeyboardSettings() }.buttonStyle(.bordered)
                }
                if !model.installMessage.isEmpty { Text(model.installMessage).font(.system(size: 12)).textSelection(.enabled) }
                Text("系統可能需要登出再登入，才會顯示新輸入法。檔案存在不代表已啟用，也不代表已通過跨 App 測試。").font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 12) {
                Text("使用前先知道").font(.headline)
                Text("• 自動模式偏向保留英文；單音節或不明確的按鍵可切到「注音優先」。\n• 選字、第一聲空白與 Enter 提交的節奏，請先在非重要文字測試。\n• 選到系統 ABC 時，順打不會處理輸入。\n• 原生輸入法以 Control + \\ 輪換自動／注音／英文模式。\n• 密碼欄位與安全輸入遵循 macOS 限制。\n• 這個版本尚未驗證 LINE、Word 等所有 App，請保留原本輸入法。")
                    .font(.system(size: 12)).lineSpacing(7)
            }
            Divider()
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("離線，且可檢查").font(.system(size: 13, weight: .semibold))
                    Text("不讀取文件或輸入歷史。\n不使用全域鍵盤監聽與雲端 API。\n詞庫 \(model.decoder.entryCount.formatted()) 筆，隨 App 附上。").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(5)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("移除與授權").font(.system(size: 13, weight: .semibold))
                    Button("開啟輸入法資料夾") { Installer.revealInputMethods() }
                    Button("查看開源授權") { Installer.openLicenses() }
                    Text("先切回 ABC 並從鍵盤設定移除順打，\n再刪除 ShunTypeInputMethod.app。").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
                }
            }
            Text("開發預覽：本機 ad-hoc 簽署，尚未取得 Developer ID 簽署與 Apple 公證。公開穩定版發布前需完成簽署、公證與跨 App 測試。")
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(14).background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
